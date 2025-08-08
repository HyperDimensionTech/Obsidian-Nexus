import Foundation
import Combine

// MARK: - Cloud Sync Provider Protocol

/// Abstract interface for cloud sync backends
public protocol CloudSyncProvider {
    var providerName: String { get }
    var isConnected: Bool { get }
    var connectionStatusPublisher: AnyPublisher<CloudConnectionStatus, Never> { get }
    
    // Connection Management
    func connect() async throws
    func disconnect() async
    func testConnection() async throws -> Bool
    
    // Event Sync
    func pushEvents(_ events: [CloudEvent]) async throws -> CloudSyncResult
    func pullEvents(since timestamp: Date?, limit: Int?) async throws -> CloudEventBatch
    func getLatestTimestamp() async throws -> Date
    
    // Real-time Updates
    func subscribeToUpdates() -> AnyPublisher<CloudEvent, CloudSyncError>
    func unsubscribeFromUpdates() async
    
    // Conflict Resolution
    func resolveConflicts(_ conflicts: [CloudConflict]) async throws -> [CloudEvent]
    
    // Device Management
    func registerDevice(_ device: CloudDevice) async throws
    func getConnectedDevices() async throws -> [CloudDevice]
}

// MARK: - Cloud Event Serialization

public struct CloudEvent: Codable, Identifiable {
    public let id: String
    public let deviceId: String
    public let timestamp: Date
    public let eventType: String
    public let aggregateId: String
    public let aggregateType: String
    public let eventData: Data
    public let vectorClock: [String: UInt64]
    public let checksum: String
    
    public init(id: String, deviceId: String, timestamp: Date, eventType: String, 
                aggregateId: String, aggregateType: String, eventData: Data, 
                vectorClock: [String: UInt64]) {
        self.id = id
        self.deviceId = deviceId
        self.timestamp = timestamp
        self.eventType = eventType
        self.aggregateId = aggregateId
        self.aggregateType = aggregateType
        self.eventData = eventData
        self.vectorClock = vectorClock
        self.checksum = CloudEvent.generateChecksum(data: eventData)
    }
    
    private static func generateChecksum(data: Data) -> String {
        return data.base64EncodedString().suffix(8).lowercased()
    }
}

// MARK: - Supporting Types

public enum CloudConnectionStatus: String, CaseIterable {
    case disconnected = "disconnected"
    case connecting = "connecting"
    case connected = "connected"
    case error = "error"
    case syncing = "syncing"
    
    public var description: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .error: return "Connection Error"
        case .syncing: return "Syncing..."
        }
    }
    
    public var isConnected: Bool {
        switch self {
        case .connected, .syncing:
            return true
        default:
            return false
        }
    }
}

public struct CloudSyncResult {
    public let successCount: Int
    public let failureCount: Int
    public let errors: [CloudSyncError]
    public let conflicts: [CloudConflict]
    public let serverTimestamp: Date
    
    public init(successCount: Int, failureCount: Int, errors: [CloudSyncError] = [], conflicts: [CloudConflict] = [], serverTimestamp: Date) {
        self.successCount = successCount
        self.failureCount = failureCount
        self.errors = errors
        self.conflicts = conflicts
        self.serverTimestamp = serverTimestamp
    }
}

public struct CloudEventBatch {
    public let events: [CloudEvent]
    public let hasMore: Bool
    public let nextToken: String?
    public let serverTimestamp: Date
    
    public init(events: [CloudEvent], hasMore: Bool = false, nextToken: String? = nil, serverTimestamp: Date) {
        self.events = events
        self.hasMore = hasMore
        self.nextToken = nextToken
        self.serverTimestamp = serverTimestamp
    }
}

public struct CloudConflict {
    public let localEvent: CloudEvent
    public let remoteEvent: CloudEvent
    public let conflictType: ConflictType
    
    public enum ConflictType {
        case concurrentUpdate
        case deletedLocally
        case deletedRemotely
        case timestampMismatch
    }
}

// Legacy type alias for backward compatibility
public typealias ConflictPair = CloudConflict

public struct CloudDevice: Codable {
    public let id: String
    public let name: String
    public let type: DeviceType
    public let lastSeen: Date
    public let appVersion: String
    
    public enum DeviceType: String, Codable, CaseIterable {
        case iphone = "iphone"
        case ipad = "ipad"
        case mac = "mac"
        case unknown = "unknown"
    }
}

public enum CloudSyncError: Error, LocalizedError {
    case notConnected
    case authenticationFailed
    case authenticationRequired(String)
    case connectionFailed(String)
    case dataCorruption(String)
    case networkError(Error)
    case serializationError(String)
    case conflictResolutionFailed
    case quotaExceeded
    case serverError(Int, String)
    case unknownError(String)
    
    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to cloud service"
        case .authenticationFailed:
            return "Authentication failed"
        case .authenticationRequired(let message):
            return "Authentication required: \(message)"
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .dataCorruption(let message):
            return "Data corruption: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serializationError(let message):
            return "Serialization error: \(message)"
        case .conflictResolutionFailed:
            return "Conflict resolution failed"
        case .quotaExceeded:
            return "Cloud storage quota exceeded"
        case .serverError(let code, let message):
            return "Server error \(code): \(message)"
        case .unknownError(let message):
            return "Unknown error: \(message)"
        }
    }
}

// MARK: - Event Serialization Extension

public extension CloudEvent {
    /// Convert from local domain event to cloud event
    static func fromDomainEvent<T: DomainEvent & Codable>(_ event: T, deviceId: DeviceID, vectorClock: VectorClock) throws -> CloudEvent {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let eventData = try encoder.encode(event)
        let clockData = vectorClock.clocks
        
        // Convert DeviceID keys to String keys
        let vectorClockDict = Dictionary(uniqueKeysWithValues: clockData.map { (key, value) in
            (key.uuid, value)
        })
        
        return CloudEvent(
            id: event.eventId.uuidString,
            deviceId: deviceId.uuid,
            timestamp: event.timestamp,
            eventType: String(describing: type(of: event)),
            aggregateId: event.aggregateId.uuidString,
            aggregateType: String(describing: T.self),
            eventData: eventData,
            vectorClock: vectorClockDict
        )
    }
    
    /// Convert back to domain event
    func toDomainEvent<T: DomainEvent & Codable>(_ type: T.Type) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(type, from: eventData)
    }
}

// MARK: - Mock Cloud Provider for Development

public class MockCloudProvider: CloudSyncProvider {
    public let providerName = "Mock Cloud"
    public private(set) var isConnected = false
    
    private let statusSubject = CurrentValueSubject<CloudConnectionStatus, Never>(.disconnected)
    public var connectionStatusPublisher: AnyPublisher<CloudConnectionStatus, Never> {
        statusSubject.eraseToAnyPublisher()
    }
    
    private let updatesSubject = PassthroughSubject<CloudEvent, CloudSyncError>()
    private var mockEvents: [CloudEvent] = []
    
    public init() {}
    
    public func connect() async throws {
        statusSubject.send(.connecting)
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        isConnected = true
        statusSubject.send(.connected)
    }
    
    public func disconnect() async {
        isConnected = false
        statusSubject.send(.disconnected)
    }
    
    public func testConnection() async throws -> Bool {
        return isConnected
    }
    
    public func pushEvents(_ events: [CloudEvent]) async throws -> CloudSyncResult {
        guard isConnected else { throw CloudSyncError.notConnected }
        
        statusSubject.send(.syncing)
        mockEvents.append(contentsOf: events)
        statusSubject.send(.connected)
        
        return CloudSyncResult(
            successCount: events.count,
            failureCount: 0,
            serverTimestamp: Date()
        )
    }
    
    public func pullEvents(since timestamp: Date?, limit: Int?) async throws -> CloudEventBatch {
        guard isConnected else { throw CloudSyncError.notConnected }
        
        let filtered = mockEvents.filter { event in
            if let since = timestamp {
                return event.timestamp > since
            }
            return true
        }
        
        let limited = Array(filtered.prefix(limit ?? 100))
        
        return CloudEventBatch(
            events: limited,
            hasMore: filtered.count > limited.count,
            serverTimestamp: Date()
        )
    }
    
    public func getLatestTimestamp() async throws -> Date {
        return mockEvents.map(\.timestamp).max() ?? Date.distantPast
    }
    
    public func subscribeToUpdates() -> AnyPublisher<CloudEvent, CloudSyncError> {
        updatesSubject.eraseToAnyPublisher()
    }
    
    public func unsubscribeFromUpdates() async {
        // Mock implementation
    }
    
    public func resolveConflicts(_ conflicts: [CloudConflict]) async throws -> [CloudEvent] {
        // Simple last-writer-wins for mock
        return conflicts.map { conflict in
            conflict.localEvent.timestamp > conflict.remoteEvent.timestamp 
                ? conflict.localEvent 
                : conflict.remoteEvent
        }
    }
    
    public func registerDevice(_ device: CloudDevice) async throws {
        // Mock implementation
    }
    
    public func getConnectedDevices() async throws -> [CloudDevice] {
        return []
    }
} 