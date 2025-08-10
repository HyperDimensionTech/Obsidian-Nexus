import Foundation
import Combine
import SwiftUI
import SQLite3

// MARK: - Local Sync Engine

public class LocalSyncEngine: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var syncStatus: SyncEngineStatus = .idle
    @Published public var lastSyncTime: Date?
    @Published public var pendingEventCount: Int = 0
    @Published public var connectionStatus: CloudConnectionStatus = .disconnected
    @Published public var syncProgress: SyncProgress = SyncProgress()
    
    // MARK: - Private Properties
    
    private let databaseManager: DatabaseManager
    private let eventStore: EventStore
    private let crdtRepository: CRDTRepository
    private var cloudProvider: CloudSyncProvider?
    private var cancellables = Set<AnyCancellable>()
    private let syncQueue = DispatchQueue(label: "sync.engine", qos: .utility)
    private var isAutoSyncEnabled = true
    private var syncTimer: Timer?
    private let deviceId: DeviceID
    private let authService: AuthenticationService
    
    // MARK: - User Isolation
    
    private var currentUserId: String? {
        return authService.currentUser?.id
    }
    
    // MARK: - Configuration
    
    private let syncInterval: TimeInterval = 30 // seconds
    private let batchSize = 50
    private let maxRetries = 3
    
    // MARK: - Initialization
    
    public init(
        databaseManager: DatabaseManager = .shared,
        deviceId: DeviceID = DeviceID(),
        authService: AuthenticationService = .shared
    ) {
        self.databaseManager = databaseManager
        self.eventStore = EventStore(database: databaseManager)
        self.crdtRepository = CRDTRepository(eventStore: eventStore, deviceId: deviceId)
        self.deviceId = deviceId
        self.authService = authService
        
        setupAutoSync()
        loadSyncState()
        observeAuthenticationState()
    }
    
    // MARK: - Public Methods
    
    /// Set the cloud provider (Supabase, Firebase, etc.)
    public func setCloudProvider(_ provider: CloudSyncProvider) {
        cloudProvider = provider
        
        // Subscribe to connection status updates
        provider.connectionStatusPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.connectionStatus, on: self)
            .store(in: &cancellables)
        
        // Subscribe to real-time updates
        provider.subscribeToUpdates()
            .receive(on: syncQueue)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("🔴 Real-time sync error: \(error)")
                    }
                },
                receiveValue: { [weak self] event in
                    Task { await self?.handleIncomingEvent(event) }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Start automatic synchronization
    public func startAutoSync() {
        isAutoSyncEnabled = true
        setupAutoSync()
    }
    
    /// Stop automatic synchronization
    public func stopAutoSync() {
        isAutoSyncEnabled = false
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    /// Manually trigger a full sync
    @MainActor
    public func manualSync() async throws {
        guard let provider = cloudProvider else {
            throw CloudSyncError.connectionFailed("No cloud provider configured")
        }
        
        guard currentUserId != nil else {
            throw CloudSyncError.authenticationRequired("User must be authenticated to sync")
        }
        
        syncStatus = .syncing
        
        do {
            try await performFullSync(with: provider)
        } catch {
            syncStatus = .error(error)
            throw error
        }
    }
    
    /// Push local changes to cloud
    public func pushLocalChanges() async throws {
        guard let provider = cloudProvider else {
            throw CloudSyncError.connectionFailed("No cloud provider configured")
        }
        
        let pendingEvents = try await getPendingEvents()
        if !pendingEvents.isEmpty {
            let result = try await provider.pushEvents(pendingEvents)
            try await handlePushResult(result, events: pendingEvents)
        }
    }
    
    /// Pull remote changes from cloud
    public func pullRemoteChanges() async throws {
        guard let provider = cloudProvider else {
            throw CloudSyncError.connectionFailed("No cloud provider configured")
        }
        
        let lastSync = lastSyncTime ?? Date.distantPast
        let remoteEventBatch = try await provider.pullEvents(since: lastSync, limit: 100)
        
        for event in remoteEventBatch.events {
            await handleIncomingEvent(event)
        }
        
        await updateLastSyncTime()
    }
    
    /// Get sync statistics
    public func getSyncStats() async throws -> SyncStats {
        let totalEvents = try eventStore.getEventCount()
        let pendingEvents = try getPendingEventCount()
        let lastSync = lastSyncTime
        
        return SyncStats(
            totalEvents: totalEvents,
            pendingEvents: pendingEvents,
            lastSyncTime: lastSync,
            connectionStatus: connectionStatus,
            syncStatus: syncStatus
        )
    }
    
    // MARK: - Private Methods
    
    private func observeAuthenticationState() {
        authService.$currentUser
            .sink { [weak self] user in
                Task {
                    await self?.handleUserChange(user)
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleUserChange(_ user: AuthenticatedUser?) async {
        if user == nil {
            // User signed out - stop sync and clear cloud provider
            stopAutoSync()
            cloudProvider = nil
            await MainActor.run {
                connectionStatus = .disconnected
                syncStatus = .idle
            }
        } else {
            // User signed in - reload sync state and resume sync
            loadSyncState()
            if isAutoSyncEnabled {
                startAutoSync()
            }
        }
    }
    
    private func setupAutoSync() {
        guard isAutoSyncEnabled else { return }
        
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task {
                try? await self?.autoSync()
            }
        }
    }
    
    private func autoSync() async throws {
        guard syncStatus != .syncing && connectionStatus.isConnected else { return }
        guard currentUserId != nil else { return } // Only sync when user is authenticated
        guard let provider = cloudProvider else { return }
        
        try await performFullSync(with: provider)
    }
    
    private func performFullSync(with provider: CloudSyncProvider) async throws {
        await MainActor.run { syncStatus = .syncing }
        
        do {
            // Step 1: Connect if needed
            if connectionStatus != .connected {
                try await provider.connect()
            }
            
            // Step 2: Push local changes
            await updateProgress(stage: .pushing, current: 0, total: 100)
            try await pushLocalChanges()
            
            // Step 3: Pull remote changes
            await updateProgress(stage: .pulling, current: 50, total: 100)
            try await pullRemoteChanges()
            
            // Step 4: Complete
            await updateProgress(stage: .complete, current: 100, total: 100)
            await MainActor.run { 
                syncStatus = .synced(Date())
                lastSyncTime = Date()
            }
            
        } catch {
            await MainActor.run { syncStatus = .error(error) }
            throw error
        }
    }
    
    private func handleIncomingEvent(_ cloudEvent: CloudEvent) async {
        do {
            // Check for conflicts
            if let existingEvent = try? eventStore.getEvent(eventId: cloudEvent.id) {
                let conflict = ConflictPair(
                    localEvent: convertStoredEventToCloud(existingEvent),
                    remoteEvent: cloudEvent,
                    conflictType: determineConflictType(stored: existingEvent, remote: cloudEvent)
                )
                try await handleConflict(conflict)
            } else {
                // No conflict, convert and save the event
                let localEvent = try convertCloudEventToLocal(cloudEvent)
                try saveConvertedEvent(localEvent)
                await updatePendingCount()
            }
            
        } catch {
            print("🔴 Failed to handle incoming event: \(error)")
        }
    }
    
    private func handlePushResult(_ result: CloudSyncResult, events: [CloudEvent]) async throws {
        // Mark successfully synced events
        for event in events {
            if result.successCount > 0 {
                try await markEventAsSynced(eventId: event.id)
            }
        }
        
        // Handle conflicts
        for conflict in result.conflicts {
            try await handleConflict(conflict)
        }
        
        await updatePendingCount()
    }
    
    private func handleConflict(_ conflict: CloudConflict) async throws {
        // For now, use Last-Writer-Wins resolution
        // In a production app, you might want more sophisticated conflict resolution
        let resolvedEvent = conflict.remoteEvent.timestamp > conflict.localEvent.timestamp 
            ? conflict.remoteEvent 
            : conflict.localEvent
            
        let localEvent = try convertCloudEventToLocal(resolvedEvent)
        try saveConvertedEvent(localEvent)
        
        print("🟡 Conflict resolved using LWW for event: \(conflict.localEvent.id)")
    }
    
    private func getPendingEvents() async throws -> [CloudEvent] {
        guard let userId = currentUserId else {
            throw CloudSyncError.authenticationRequired("User must be authenticated to get pending events")
        }
        
        // Get events that haven't been synced to cloud for the current user
        let sql = """
            SELECT event_id, aggregate_id, aggregate_type, event_type, event_data, 
                   vector_clock, device_id, timestamp, version
            FROM crdt_events 
            WHERE user_id = ? AND event_id NOT IN (
                SELECT id FROM cloud_sync_metadata WHERE sync_status = 'synced' AND user_id = ?
            )
            ORDER BY timestamp ASC 
            LIMIT \(batchSize);
        """
        
        var events: [CloudEvent] = []
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(databaseManager.connection, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseManager.DatabaseError.prepareFailed("Failed to prepare pending events query")
        }
        
        defer { sqlite3_finalize(statement) }
        
        // Bind user ID parameters
        sqlite3_bind_text(statement, 1, userId, -1, nil)
        sqlite3_bind_text(statement, 2, userId, -1, nil)
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let eventId = String(cString: sqlite3_column_text(statement, 0))
            let aggregateId = String(cString: sqlite3_column_text(statement, 1))
            let aggregateType = String(cString: sqlite3_column_text(statement, 2))
            let eventType = String(cString: sqlite3_column_text(statement, 3))
            let eventData = Data(bytes: sqlite3_column_blob(statement, 4), count: Int(sqlite3_column_bytes(statement, 4)))
            _ = String(cString: sqlite3_column_text(statement, 5))
            let deviceId = String(cString: sqlite3_column_text(statement, 6))
            let timestamp = Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 7)))
            _ = Int(sqlite3_column_int64(statement, 8))
            
            let cloudEvent = CloudEvent(
                id: eventId,
                deviceId: deviceId,
                timestamp: timestamp,
                eventType: eventType,
                aggregateId: aggregateId,
                aggregateType: aggregateType,
                eventData: eventData,
                vectorClock: [:]
            )
            
            events.append(cloudEvent)
        }
        
        return events
    }
    
    private func getPendingEventCount() throws -> Int {
        guard let userId = currentUserId else {
            return 0 // No user authenticated, no pending events
        }
        
        let sql = """
            SELECT COUNT(*) FROM crdt_events 
            WHERE user_id = ? AND event_id NOT IN (
                SELECT id FROM cloud_sync_metadata WHERE sync_status = 'synced' AND user_id = ?
            );
        """
        
        var statement: OpaquePointer?
        var count = 0
        
        if sqlite3_prepare_v2(databaseManager.connection, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, userId, -1, nil)
            sqlite3_bind_text(statement, 2, userId, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                count = Int(sqlite3_column_int64(statement, 0))
            }
        }
        
        sqlite3_finalize(statement)
        return count
    }
    
    private func markEventAsSynced(eventId: String) async throws {
        guard let userId = currentUserId else {
            throw CloudSyncError.authenticationRequired("User must be authenticated to mark events as synced")
        }
        
        let sql = """
            INSERT OR REPLACE INTO cloud_sync_metadata 
            (id, user_id, cloud_provider, sync_status, last_cloud_sync, created_at, updated_at)
            VALUES (?, ?, ?, 'synced', ?, ?, ?);
        """
        
        let timestamp = Int(Date().timeIntervalSince1970)
        try databaseManager.executeStatement(sql, parameters: [
            eventId,
            userId,
            cloudProvider?.providerName ?? "unknown",
            timestamp,
            timestamp,
            timestamp
        ])
    }
    
    private func convertCloudEventToLocal(_ cloudEvent: CloudEvent) throws -> Any {
        // This would convert CloudSyncEvent back to the appropriate local event type
        // For now, we'll use a simplified approach
        switch cloudEvent.aggregateType {
        case "InventoryItem":
            return try convertToInventoryItemEvent(cloudEvent)
        case "Location":
            return try convertToLocationEvent(cloudEvent)
        default:
            throw CloudSyncError.dataCorruption("Unknown aggregate type: \(cloudEvent.aggregateType)")
        }
    }
    
    private func convertToInventoryItemEvent(_ cloudEvent: CloudEvent) throws -> InventoryItemEvent {
        // Simplified conversion - in a real implementation you'd deserialize the eventData
        // and create the appropriate event type based on eventType
        let itemCreated = InventoryItemCreated(
            aggregateId: UUID(uuidString: cloudEvent.aggregateId) ?? UUID(),
            deviceId: DeviceID(uuid: cloudEvent.deviceId),
            version: 1,
            title: "Synced Item", // Would be extracted from eventData
            type: "books",
            condition: "good"
        )
        return .created(itemCreated)
    }
    
    private func convertToLocationEvent(_ cloudEvent: CloudEvent) throws -> LocationEvent {
        // Simplified conversion
        let locationCreated = LocationCreated(
            aggregateId: UUID(uuidString: cloudEvent.aggregateId) ?? UUID(),
            deviceId: DeviceID(uuid: cloudEvent.deviceId),
            version: 1,
            name: "Synced Location", // Would be extracted from eventData
            type: "room",
            parentId: nil
        )
        return .created(locationCreated)
    }
    
    private func convertStoredEventToCloud(_ storedEvent: StoredEvent) -> CloudEvent {
        // Convert stored event to CloudSyncEvent
        return CloudEvent(
            id: storedEvent.eventId.uuidString,
            deviceId: storedEvent.deviceId.uuid,
            timestamp: storedEvent.timestamp,
            eventType: storedEvent.eventType,
            aggregateId: storedEvent.aggregateId.uuidString,
            aggregateType: "InventoryItem", // Would be determined from eventType
            eventData: storedEvent.eventData,
            vectorClock: [:] // TODO: Convert vector clock properly
        )
    }
    
    private func determineConflictType(stored: StoredEvent, remote: CloudEvent) -> CloudConflict.ConflictType {
        // Simplified conflict detection
        return .concurrentUpdate
    }
    
    private func saveConvertedEvent(_ event: Any) throws {
        // Save the converted event based on its type
        if let inventoryEvent = event as? InventoryItemEvent {
            try eventStore.saveEvent(inventoryEvent)
        } else if let locationEvent = event as? LocationEvent {
            try eventStore.saveEvent(locationEvent)
        } else {
            throw CloudSyncError.dataCorruption("Unknown event type for saving")
        }
    }
    
    private func updateProgress(stage: SyncStage, current: Int, total: Int) async {
        await MainActor.run {
            syncProgress = SyncProgress(stage: stage, current: current, total: total)
        }
    }
    
    private func updatePendingCount() async {
        if let count = try? getPendingEventCount() {
            await MainActor.run {
                pendingEventCount = count
            }
        }
    }
    
    private func updateLastSyncTime() async {
        await MainActor.run {
            lastSyncTime = Date()
        }
        
        // Save sync time to database
        saveSyncState()
    }
    
    private func saveSyncState() {
        guard let userId = currentUserId, let syncTime = lastSyncTime else { return }
        
        let sql = """
            INSERT OR REPLACE INTO sync_state 
            (key, user_id, value, updated_at) 
            VALUES ('last_sync_time', ?, ?, ?);
        """
        
        let timestamp = Int(Date().timeIntervalSince1970)
        do {
            try databaseManager.executeStatement(sql, parameters: [
                userId,
                Int(syncTime.timeIntervalSince1970),
                timestamp
            ])
        } catch {
            print("🔴 Failed to save sync state: \(error)")
        }
    }
    
    private func loadSyncState() {
        guard let userId = currentUserId else {
            // No user authenticated, reset sync state
            lastSyncTime = nil
            Task {
                await MainActor.run {
                    pendingEventCount = 0
                }
            }
            return
        }
        
        // Load last sync time from database for current user
        let sql = "SELECT value FROM sync_state WHERE key = 'last_sync_time' AND user_id = ?;"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(databaseManager.connection, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, userId, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                let timestamp = sqlite3_column_int64(statement, 0)
                lastSyncTime = Date(timeIntervalSince1970: TimeInterval(timestamp))
            }
        }
        sqlite3_finalize(statement)
        
        // Update pending count
        Task {
            await updatePendingCount()
        }
    }
}

// MARK: - Supporting Types

public enum SyncEngineStatus: Equatable {
    case idle
    case syncing
    case synced(Date)
    case error(Error)
    
    public static func == (lhs: SyncEngineStatus, rhs: SyncEngineStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.syncing, .syncing):
            return true
        case (.synced(let date1), .synced(let date2)):
            return date1 == date2
        case (.error, .error):
            return true
        default:
            return false
        }
    }
    
    public var description: String {
        switch self {
        case .idle:
            return "Ready"
        case .syncing:
            return "Syncing..."
        case .synced(let date):
            let formatter = RelativeDateTimeFormatter()
            return "Synced \(formatter.localizedString(for: date, relativeTo: Date()))"
        case .error(let error):
            return "Error: \(error.localizedDescription)"
        }
    }
}

public enum SyncStage: String, CaseIterable {
    case pushing = "pushing"
    case pulling = "pulling"
    case resolving = "resolving"
    case complete = "complete"
    
    public var description: String {
        switch self {
        case .pushing: return "Pushing local changes..."
        case .pulling: return "Pulling remote changes..."
        case .resolving: return "Resolving conflicts..."
        case .complete: return "Sync complete"
        }
    }
}

public struct SyncProgress {
    public let stage: SyncStage
    public let current: Int
    public let total: Int
    
    public init(stage: SyncStage = .pushing, current: Int = 0, total: Int = 100) {
        self.stage = stage
        self.current = current
        self.total = total
    }
    
    public var progress: Double {
        guard total > 0 else { return 0 }
        return Double(current) / Double(total)
    }
}

public struct SyncStats {
    public let totalEvents: Int
    public let pendingEvents: Int
    public let lastSyncTime: Date?
    public let connectionStatus: CloudConnectionStatus
    public let syncStatus: SyncEngineStatus
    
    public init(
        totalEvents: Int,
        pendingEvents: Int,
        lastSyncTime: Date?,
        connectionStatus: CloudConnectionStatus,
        syncStatus: SyncEngineStatus
    ) {
        self.totalEvents = totalEvents
        self.pendingEvents = pendingEvents
        self.lastSyncTime = lastSyncTime
        self.connectionStatus = connectionStatus
        self.syncStatus = syncStatus
    }
} 
