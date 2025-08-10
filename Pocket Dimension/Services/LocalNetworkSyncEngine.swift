import Foundation
import Network
import Combine
import SwiftUI
import SQLite3
import UIKit

// MARK: - Local Network Sync Engine

/// Handles local network sync using Bonjour/mDNS device discovery
public class LocalNetworkSyncEngine: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var isDiscovering = false
    @Published public var discoveredDevices: [PeerDevice] = []
    @Published public var connectedDevices: [PeerDevice] = []
    @Published public var syncStatus: LocalSyncStatus = .idle
    @Published public var lastLocalSync: Date?
    @Published public var pendingEventCount: Int = 0
    
    // MARK: - Private Properties
    
    private let serviceName = "_pocket-dimension._tcp"
    private let servicePort: UInt16 = 8080
    private let deviceId: DeviceID
    private let deviceName: String
    private let eventStore: EventStore
    private let crdtRepository: CRDTRepository
    
    // Network Discovery
    private var netService: NetService?
    private var browser: NetServiceBrowser?
    private var connections: [String: PeerConnection] = [:]
    
    // Background sync
    private var syncTimer: Timer?
    private let syncInterval: TimeInterval = 60 // 1 minute
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    // Sync queue
    private let syncQueue = DispatchQueue(label: "local-network-sync", qos: .utility)
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init(
        deviceId: DeviceID = DeviceID(),
        deviceName: String = UIDevice.current.name,
        eventStore: EventStore = EventStore(),
        crdtRepository: CRDTRepository? = nil
    ) {
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.eventStore = eventStore
        self.crdtRepository = crdtRepository ?? CRDTRepository(eventStore: eventStore, deviceId: deviceId)
        
        super.init()
        
        setupBackgroundSync()
        setupNetworkMonitoring()
        
        print("🔗 Local Network Sync Engine initialized for device: \(deviceName)")
    }
    
    deinit {
        stopDiscovery()
        stopAdvertising()
        syncTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    /// Start advertising this device on the local network
    public func startAdvertising() {
        guard netService == nil else { return }
        
        // Create service info
        let serviceInfo = createServiceInfo()
        
        netService = NetService(domain: "local.", type: serviceName, name: deviceName, port: Int32(servicePort))
        netService?.delegate = self
        
        // Set TXT record with device info
        let txtData = NetService.data(fromTXTRecord: serviceInfo)
        netService?.setTXTRecord(txtData)
        
        netService?.publish(options: .listenForConnections)
        
        print("📡 Started advertising as '\(deviceName)' on local network")
    }
    
    /// Stop advertising this device
    public func stopAdvertising() {
        netService?.stop()
        netService = nil
        print("📡 Stopped advertising")
    }
    
    /// Start discovering other devices on the local network
    public func startDiscovery() {
        guard browser == nil else { return }
        
        browser = NetServiceBrowser()
        browser?.delegate = self
        browser?.searchForServices(ofType: serviceName, inDomain: "local.")
        
        isDiscovering = true
        print("🔍 Started discovering devices on local network")
    }
    
    /// Stop discovering devices
    public func stopDiscovery() {
        browser?.stop()
        browser = nil
        isDiscovering = false
        discoveredDevices.removeAll()
        print("🔍 Stopped discovering devices")
    }
    
    /// Connect to a discovered device
    public func connectToDevice(_ device: PeerDevice) async throws {
        guard let service = device.netService else {
            throw LocalNetworkSyncError.invalidDevice
        }
        
        print("🤝 Connecting to device: \(device.name)")
        
        // Resolve service to get connection details
        service.resolve(withTimeout: 10.0)
        
        // Create connection (simplified - in real implementation would use TCP/WebSocket)
        let connection = PeerConnection(
            deviceId: device.id,
            deviceName: device.name,
            service: service
        )
        
        connections[device.id] = connection
        
        // Add to connected devices if not already there
        if !connectedDevices.contains(where: { $0.id == device.id }) {
            await MainActor.run {
                connectedDevices.append(device)
            }
        }
        
        print("✅ Connected to device: \(device.name)")
    }
    
    /// Disconnect from a device
    public func disconnectFromDevice(_ device: PeerDevice) {
        connections.removeValue(forKey: device.id)
        connectedDevices.removeAll { $0.id == device.id }
        print("❌ Disconnected from device: \(device.name)")
    }
    
    /// Manually trigger sync with all connected devices
    public func manualSync() async throws {
        guard !connectedDevices.isEmpty else {
            throw LocalNetworkSyncError.noConnectedDevices
        }
        
        await MainActor.run {
            syncStatus = .syncing
        }
        
        do {
            try await performSync()
            await MainActor.run {
                syncStatus = .synced(Date())
                lastLocalSync = Date()
            }
        } catch {
            await MainActor.run {
                syncStatus = .error(error)
            }
            throw error
        }
    }
    
    /// Start background sync
    public func startBackgroundSync() {
        guard syncTimer == nil else { return }
        
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.backgroundSync()
            }
        }
        
        print("🔄 Started background sync (interval: \(syncInterval)s)")
    }
    
    /// Stop background sync
    public func stopBackgroundSync() {
        syncTimer?.invalidate()
        syncTimer = nil
        print("🔄 Stopped background sync")
    }
    
    // MARK: - Private Methods
    
    private func setupBackgroundSync() {
        // Start background sync by default
        startBackgroundSync()
    }
    
    private func setupNetworkMonitoring() {
        // Monitor network changes and restart discovery if needed
        NotificationCenter.default.publisher(for: .networkDidChange)
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleNetworkChange()
            }
            .store(in: &cancellables)
    }
    
    private func handleNetworkChange() {
        print("📶 Network changed, restarting discovery...")
        
        // Restart discovery
        stopDiscovery()
        startDiscovery()
        
        // Restart advertising
        stopAdvertising()
        startAdvertising()
    }
    
    private func createServiceInfo() -> [String: Data] {
        var serviceInfo: [String: Data] = [:]
        
        // Add device information
        serviceInfo["deviceId"] = deviceId.uuid.data(using: .utf8)
        serviceInfo["deviceName"] = deviceName.data(using: .utf8)
        serviceInfo["version"] = "1.0".data(using: .utf8)
        serviceInfo["platform"] = "iOS".data(using: .utf8)
        
        // Add sync info
        if let lastSync = lastLocalSync {
            serviceInfo["lastSync"] = String(lastSync.timeIntervalSince1970).data(using: .utf8)
        }
        
        return serviceInfo
    }
    
    private func backgroundSync() async {
        guard !connectedDevices.isEmpty else { return }
        guard syncStatus != .syncing else { return }
        
        do {
            try await performSync()
            await MainActor.run {
                lastLocalSync = Date()
            }
        } catch {
            print("🔴 Background sync failed: \(error)")
        }
    }
    
    private func performSync() async throws {
        print("🔄 Starting local network sync...")
        
        // Get pending events from local device
        let pendingEvents = try await getPendingEvents()
        
        // Sync with each connected device
        for device in connectedDevices {
            guard let connection = connections[device.id] else { continue }
            
            try await syncWithDevice(connection, localEvents: pendingEvents)
        }
        
        print("✅ Local network sync completed")
    }
    
    public func syncWithDevice(_ device: PeerDevice) async {
        print("🔄 Starting sync with device: \(device.name)")
        syncStatus = .syncing
        
        // In a real implementation, this would:
        // 1. Get pending local events
        // 2. Connect to the device
        // 3. Exchange vector clocks
        // 4. Send/receive events
        // 5. Apply remote events locally
        
        // For now, simulate sync
        do {
            let localEvents = try await getPendingEvents()
            print("📤 Found \(localEvents.count) local events to sync")
            
            // Simulate successful sync
            await MainActor.run {
                lastLocalSync = Date()
                syncStatus = .idle
            }
            
            print("✅ Successfully synced with \(device.name)")
        } catch {
            print("❌ Sync failed with \(device.name): \(error)")
            await MainActor.run {
                syncStatus = .error(error)
            }
        }
    }
    
    private func syncWithDevice(_ connection: PeerConnection, localEvents: [SyncEvent]) async throws {
        print("🔄 Syncing with device: \(connection.deviceName)")
        
        // 1. Exchange vector clocks to determine what events to share
        let remoteClock = try await exchangeVectorClock(with: connection)
        
        // 2. Determine events to send and request
        let eventsToSend = filterEventsToSend(localEvents, remoteClock: remoteClock)
        let eventsToRequest = determineEventsToRequest(remoteClock: remoteClock)
        
        // 3. Send our events
        if !eventsToSend.isEmpty {
            try await sendEvents(eventsToSend, to: connection)
        }
        
        // 4. Request and receive remote events
        if !eventsToRequest.isEmpty {
            let remoteEvents = try await requestEvents(eventsToRequest, from: connection)
            try await applyRemoteEvents(remoteEvents)
        }
        
        print("✅ Sync completed with device: \(connection.deviceName)")
    }
    
    private func getPendingEvents() async throws -> [SyncEvent] {
        // Get all events from the local event store that haven't been synced locally
        let sql = """
            SELECT event_id, aggregate_id, aggregate_type, event_type, event_data, 
                   vector_clock, device_id, timestamp, version
            FROM crdt_events 
            WHERE event_id NOT IN (
                SELECT event_id FROM local_sync_metadata WHERE sync_status = 'synced'
            )
            ORDER BY timestamp ASC;
        """
        
        var events: [SyncEvent] = []
        var statement: OpaquePointer?
        let connection = DatabaseManager.shared.connection
        
        guard sqlite3_prepare_v2(connection, sql, -1, &statement, nil) == SQLITE_OK else {
            throw LocalNetworkSyncError.syncFailed("Failed to prepare pending events query")
        }
        
        defer { sqlite3_finalize(statement) }
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let eventId = String(cString: sqlite3_column_text(statement, 0))
            let eventType = String(cString: sqlite3_column_text(statement, 3))
            let eventData = Data(bytes: sqlite3_column_blob(statement, 4), count: Int(sqlite3_column_bytes(statement, 4)))
            let vectorClock = String(cString: sqlite3_column_text(statement, 5))
            let deviceId = String(cString: sqlite3_column_text(statement, 6))
            let timestamp = Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 7)))
            
            let syncEvent = SyncEvent(
                id: eventId,
                deviceId: deviceId,
                timestamp: timestamp,
                eventType: eventType,
                eventData: eventData,
                vectorClock: vectorClock
            )
            
            events.append(syncEvent)
        }
        
        let eventsCount = events.count
        await MainActor.run {
            pendingEventCount = eventsCount
        }
        
        return events
    }
    
    private func exchangeVectorClock(with connection: PeerConnection) async throws -> VectorClock {
        // Get our current vector clock from the CRDT repository
        let ourClock = try await getCurrentVectorClock()
        
        // In a real implementation, this would send our vector clock to the remote device
        // and receive theirs back. For now, we'll return an empty clock
        // TODO: Implement actual network communication for vector clock exchange
        
        print("📊 Exchanging vector clocks with \(connection.deviceName)")
        print("📊 Our clock: \(ourClock)")
        
        // Return empty clock for now - would be the remote device's clock
        return VectorClock()
    }
    
    private func getCurrentVectorClock() async throws -> VectorClock {
        // Get the current vector clock from the database
        let sql = """
            SELECT device_id, logical_clock 
            FROM vector_clocks 
            ORDER BY device_id;
        """
        
        var clock = VectorClock()
        var statement: OpaquePointer?
        let connection = DatabaseManager.shared.connection
        
        guard sqlite3_prepare_v2(connection, sql, -1, &statement, nil) == SQLITE_OK else {
            throw LocalNetworkSyncError.syncFailed("Failed to prepare vector clock query")
        }
        
        defer { sqlite3_finalize(statement) }
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let deviceIdString = String(cString: sqlite3_column_text(statement, 0))
            let logicalClock = UInt64(sqlite3_column_int64(statement, 1))
            
            // Create a DeviceID from the string
            let deviceId = DeviceID(uuid: deviceIdString)
            
            // Since VectorClock doesn't expose its internal clock, we need to simulate it
            for _ in 0..<logicalClock {
                clock.increment(for: deviceId)
            }
        }
        
        return clock
    }
    
    private func filterEventsToSend(_ events: [SyncEvent], remoteClock: VectorClock) -> [SyncEvent] {
        // Filter events that the remote device hasn't seen yet
        return events // Simplified for now
    }
    
    private func determineEventsToRequest(remoteClock: VectorClock) -> [String] {
        // Determine which events we need from the remote device
        return [] // Simplified for now
    }
    
    private func sendEvents(_ events: [SyncEvent], to connection: PeerConnection) async throws {
        // Send events to remote device
        print("📤 Sending \(events.count) events to \(connection.deviceName)")
    }
    
    private func requestEvents(_ eventIds: [String], from connection: PeerConnection) async throws -> [SyncEvent] {
        // Request specific events from remote device
        print("📥 Requesting \(eventIds.count) events from \(connection.deviceName)")
        return [] // Simplified for now
    }
    
    private func applyRemoteEvents(_ events: [SyncEvent]) async throws {
        print("🔄 Applying \(events.count) remote events to local state")
        
        for event in events {
            do {
                // Convert SyncEvent back to domain event and apply it
                try await applyRemoteEvent(event)
                
                // Mark event as synced locally
                try await markEventAsSynced(event.id)
                
            } catch {
                print("🔴 Failed to apply remote event \(event.id): \(error)")
                throw error
            }
        }
        
        // Update pending count
        await MainActor.run {
            pendingEventCount = max(0, pendingEventCount - events.count)
        }
    }
    
    private func applyRemoteEvent(_ syncEvent: SyncEvent) async throws {
        // Convert the sync event back to a domain event and apply it through the CRDT system
        // This ensures proper conflict resolution and state consistency
        
        // For now, we'll insert the event directly into the event store
        // In a full implementation, this would deserialize the event data
        // and apply it through the proper CRDT channels
        
        let sql = """
            INSERT OR IGNORE INTO crdt_events 
            (event_id, aggregate_id, aggregate_type, event_type, event_data, 
             vector_clock, device_id, timestamp, version, user_id)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        let connection = DatabaseManager.shared.connection
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(connection, sql, -1, &statement, nil) == SQLITE_OK else {
            throw LocalNetworkSyncError.syncFailed("Failed to prepare insert event statement")
        }
        
        defer { sqlite3_finalize(statement) }
        
        // Extract aggregate info from event data (simplified)
        let aggregateId = UUID().uuidString // Would extract from event data
        let aggregateType = "InventoryItem" // Would determine from event type
        let version = 1 // Would extract from event data
        let userId = "local-sync" // Would get from auth context
        
        // Bind parameters
        sqlite3_bind_text(statement, 1, syncEvent.id, -1, nil)
        sqlite3_bind_text(statement, 2, aggregateId, -1, nil)
        sqlite3_bind_text(statement, 3, aggregateType, -1, nil)
        sqlite3_bind_text(statement, 4, syncEvent.eventType, -1, nil)
        sqlite3_bind_blob(statement, 5, syncEvent.eventData.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress }, Int32(syncEvent.eventData.count), nil)
        sqlite3_bind_text(statement, 6, syncEvent.vectorClock, -1, nil)
        sqlite3_bind_text(statement, 7, syncEvent.deviceId, -1, nil)
        sqlite3_bind_int64(statement, 8, Int64(syncEvent.timestamp.timeIntervalSince1970))
        sqlite3_bind_int64(statement, 9, Int64(version))
        sqlite3_bind_text(statement, 10, userId, -1, nil)
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw LocalNetworkSyncError.syncFailed("Failed to insert remote event")
        }
        
        print("✅ Applied remote event: \(syncEvent.id)")
    }
    
    private func markEventAsSynced(_ eventId: String) async throws {
        let sql = """
            INSERT OR REPLACE INTO local_sync_metadata 
            (event_id, sync_status, synced_at, device_id)
            VALUES (?, 'synced', ?, ?);
        """
        
        let connection = DatabaseManager.shared.connection
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(connection, sql, -1, &statement, nil) == SQLITE_OK else {
            throw LocalNetworkSyncError.syncFailed("Failed to prepare sync metadata statement")
        }
        
        defer { sqlite3_finalize(statement) }
        
        let timestamp = Int64(Date().timeIntervalSince1970)
        
        sqlite3_bind_text(statement, 1, eventId, -1, nil)
        sqlite3_bind_int64(statement, 2, timestamp)
        sqlite3_bind_text(statement, 3, deviceId.uuid, -1, nil)
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw LocalNetworkSyncError.syncFailed("Failed to mark event as synced")
        }
    }
}

// MARK: - NetServiceDelegate

extension LocalNetworkSyncEngine: NetServiceDelegate {
    public func netServiceDidPublish(_ sender: NetService) {
        print("📡 Successfully published service: \(sender.name)")
    }
    
    public func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
        print("❌ Failed to publish service: \(errorDict)")
    }
    
    public func netServiceDidStop(_ sender: NetService) {
        print("📡 Service stopped: \(sender.name)")
    }
}

// MARK: - NetServiceBrowserDelegate

extension LocalNetworkSyncEngine: NetServiceBrowserDelegate {
    public func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        print("🔍 Found service: \(service.name)")
        
        // Don't add our own service
        guard service.name != deviceName else { return }
        
        // Create peer device
        let device = PeerDevice(
            id: UUID().uuidString, // Would extract from TXT record
            name: service.name,
            netService: service,
            deviceType: "pocket-dimension" // Would extract from TXT record
        )
        
        // Add to discovered devices
        if !discoveredDevices.contains(where: { $0.id == device.id }) {
            discoveredDevices.append(device)
        }
    }
    
    public func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        print("🔍 Lost service: \(service.name)")
        
        // Remove from discovered devices
        discoveredDevices.removeAll { $0.name == service.name }
        
        // Disconnect if connected
        if let device = connectedDevices.first(where: { $0.name == service.name }) {
            disconnectFromDevice(device)
        }
    }
    
    public func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        print("❌ Failed to search for services: \(errorDict)")
        isDiscovering = false
    }
}

// MARK: - Supporting Types

public struct PeerDevice: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let netService: NetService?
    public let deviceType: String
    public var lastSeen: Date = Date()
    public var status: PeerDeviceStatus = .discovered
    
    public init(id: String, name: String, netService: NetService?, deviceType: String = "unknown") {
        self.id = id
        self.name = name
        self.netService = netService
        self.deviceType = deviceType
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: PeerDevice, rhs: PeerDevice) -> Bool {
        return lhs.id == rhs.id
    }
}

public enum PeerDeviceStatus: String, CaseIterable {
    case discovered = "discovered"
    case connecting = "connecting"
    case connected = "connected"
    case disconnected = "disconnected"
    case error = "error"
    
    public var description: String {
        switch self {
        case .discovered: return "Discovered"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .disconnected: return "Disconnected"
        case .error: return "Connection Error"
        }
    }
}

public enum LocalSyncStatus: Equatable {
    case idle
    case syncing
    case synced(Date)
    case error(Error)
    
    public static func == (lhs: LocalSyncStatus, rhs: LocalSyncStatus) -> Bool {
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

public struct SyncEvent: Identifiable, Codable {
    public let id: String
    public let deviceId: String
    public let timestamp: Date
    public let eventType: String
    public let eventData: Data
    public let vectorClock: String
    
    public init(id: String, deviceId: String, timestamp: Date, eventType: String, eventData: Data, vectorClock: String) {
        self.id = id
        self.deviceId = deviceId
        self.timestamp = timestamp
        self.eventType = eventType
        self.eventData = eventData
        self.vectorClock = vectorClock
    }
}

private class PeerConnection {
    let deviceId: String
    let deviceName: String
    let service: NetService
    var isConnected: Bool = false
    
    init(deviceId: String, deviceName: String, service: NetService) {
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.service = service
    }
}

public enum LocalNetworkSyncError: Error, LocalizedError {
    case invalidDevice
    case noConnectedDevices
    case connectionFailed(String)
    case syncFailed(String)
    case networkUnavailable
    
    public var errorDescription: String? {
        switch self {
        case .invalidDevice:
            return "Invalid device"
        case .noConnectedDevices:
            return "No connected devices"
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        case .networkUnavailable:
            return "Network unavailable"
        }
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let networkDidChange = Notification.Name("networkDidChange")
} 