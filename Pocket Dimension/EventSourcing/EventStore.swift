import Foundation
import SQLite3

/// Event store for persisting and retrieving domain events
public class EventStore {
    private let db: DatabaseManager
    private let tableName = "crdt_events"
    
    public init(database: DatabaseManager = .shared) {
        self.db = database
        setupEventTable()
    }
    
    // MARK: - Event Persistence
    
    /// Save a domain event to the store
    public func saveEvent<T: DomainEvent>(_ event: T) throws {
        let sql = """
            INSERT INTO \(tableName) (
                event_id, aggregate_id, aggregate_type, event_type, event_data, 
                vector_clock, device_id, timestamp, version
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        let eventData = try JSONEncoder().encode(event)
        let eventType = String(describing: type(of: event))
        let aggregateType = getAggregateType(from: eventType)
        
        let parameters: [Any] = [
            event.eventId.uuidString,
            event.aggregateId.uuidString,
            aggregateType,
            eventType,
            eventData,
            "{}",  // Empty vector clock for now
            event.deviceId.uuid,
            Int(event.timestamp.timeIntervalSince1970),
            event.version
        ]
        
        try db.executeStatement(sql, parameters: parameters)
    }
    
    /// Save multiple events in a single transaction
    public func saveEvents<T: DomainEvent>(_ events: [T]) throws {
        guard !events.isEmpty else { return }
        
        try db.beginTransaction()
        
        do {
            for event in events {
                try saveEvent(event)
            }
            try db.commitTransaction()
        } catch {
            try? db.rollbackTransaction()
            throw error
        }
    }
    
    // MARK: - Event Retrieval
    
    /// Get all events for a specific aggregate
    public func getEvents(for aggregateId: UUID) throws -> [StoredEvent] {
        let sql = """
            SELECT event_id, aggregate_id, event_type, event_data, 
                   timestamp, device_id, version
            FROM \(tableName) 
            WHERE aggregate_id = ?
            ORDER BY version ASC;
        """
        
        return try fetchEvents(sql: sql, parameters: [aggregateId.uuidString])
    }
    
    /// Get events for a specific aggregate starting from a version
    public func getEvents(for aggregateId: UUID, fromVersion: Int) throws -> [StoredEvent] {
        let sql = """
            SELECT event_id, aggregate_id, event_type, event_data, 
                   timestamp, device_id, version
            FROM \(tableName) 
            WHERE aggregate_id = ? AND version >= ?
            ORDER BY version ASC;
        """
        
        return try fetchEvents(sql: sql, parameters: [aggregateId.uuidString, fromVersion])
    }
    
    /// Get all events since a specific timestamp (for synchronization)
    public func getEventsSince(_ timestamp: Date) throws -> [StoredEvent] {
        let sql = """
            SELECT event_id, aggregate_id, event_type, event_data, 
                   timestamp, device_id, version
            FROM \(tableName) 
            WHERE timestamp > ?
            ORDER BY timestamp ASC;
        """
        
        return try fetchEvents(sql: sql, parameters: [Int(timestamp.timeIntervalSince1970)])
    }
    
    /// Get all events (for loading initial state)
    public func getAllEvents() throws -> [StoredEvent] {
        let sql = """
            SELECT event_id, aggregate_id, event_type, event_data, 
                   timestamp, device_id, version
            FROM \(tableName) 
            ORDER BY timestamp ASC;
        """
        
        return try fetchEvents(sql: sql, parameters: [])
    }
    
    /// Get events from a specific device (useful for conflict resolution)
    public func getEvents(from deviceId: DeviceID, since timestamp: Date) throws -> [StoredEvent] {
        let sql = """
            SELECT event_id, aggregate_id, event_type, event_data, 
                   timestamp, device_id, version
            FROM \(tableName) 
            WHERE device_id = ? AND timestamp > ?
            ORDER BY timestamp ASC;
        """
        
        return try fetchEvents(sql: sql, parameters: [deviceId.uuid, Int(timestamp.timeIntervalSince1970)])
    }
    
    /// Get the current version of an aggregate
    public func getCurrentVersion(for aggregateId: UUID) throws -> Int {
        let sql = """
            SELECT MAX(version) FROM \(tableName) 
            WHERE aggregate_id = ?;
        """
        
        var statement: OpaquePointer?
        var version = 0
        
        guard sqlite3_prepare_v2(db.connection, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseManager.DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db.connection)))
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_text(statement, 1, (aggregateId.uuidString as NSString).utf8String, -1, nil)
        
        if sqlite3_step(statement) == SQLITE_ROW {
            version = Int(sqlite3_column_int64(statement, 0))
        }
        
        return version
    }
    
    // MARK: - Event Stream Management
    
    /// Get a stream of events for replay
    public func getEventStream(batchSize: Int = 100) throws -> EventStream {
        return EventStream(eventStore: self, batchSize: batchSize)
    }
    
    /// Delete events older than a specified date (for cleanup)
    public func deleteEventsOlderThan(_ date: Date) throws {
        let sql = """
            DELETE FROM \(tableName) 
            WHERE timestamp < ?;
        """
        
        try db.executeStatement(sql, parameters: [Int(date.timeIntervalSince1970)])
    }
    
    /// Get total count of events (for sync statistics)
    public func getEventCount() throws -> Int {
        let sql = "SELECT COUNT(*) FROM \(tableName);"
        return Int(db.executeScalar(sql))
    }
    
    /// Get a specific event by ID (for conflict resolution)
    public func getEvent(eventId: String) throws -> StoredEvent? {
        let sql = """
            SELECT event_id, aggregate_id, event_type, event_data, 
                   timestamp, device_id, version
            FROM \(tableName) 
            WHERE event_id = ?;
        """
        
        let events = try fetchEvents(sql: sql, parameters: [eventId])
        return events.first
    }
    
    // MARK: - Private Methods
    
    private func setupEventTable() {
        // Table creation is handled by DatabaseSchema.createCRDTSchema
        // We don't need to create it again here
    }
    
    private func getAggregateType(from eventType: String) -> String {
        if eventType.contains("InventoryItem") {
            return "InventoryItem"
        } else if eventType.contains("Location") {
            return "Location"
        } else {
            return "Unknown"
        }
    }
    
    internal func fetchEvents(sql: String, parameters: [Any] = []) throws -> [StoredEvent] {
        var events: [StoredEvent] = []
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db.connection, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseManager.DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db.connection)))
        }
        
        defer { sqlite3_finalize(statement) }
        
        // Bind parameters
        for (index, param) in parameters.enumerated() {
            let idx = Int32(index + 1)
            
            switch param {
            case let text as String:
                sqlite3_bind_text(statement, idx, (text as NSString).utf8String, -1, nil)
            case let int as Int:
                sqlite3_bind_int64(statement, idx, Int64(int))
            default:
                break
            }
        }
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let eventId = UUID(uuidString: String(cString: sqlite3_column_text(statement, 0))) ?? UUID()
            let aggregateId = UUID(uuidString: String(cString: sqlite3_column_text(statement, 1))) ?? UUID()
            let eventType = String(cString: sqlite3_column_text(statement, 2))
            let eventData = Data(bytes: sqlite3_column_blob(statement, 3), count: Int(sqlite3_column_bytes(statement, 3)))
            let timestamp = Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 4)))
            let deviceId = DeviceID(uuid: String(cString: sqlite3_column_text(statement, 5)))
            let version = Int(sqlite3_column_int64(statement, 6))
            
            let storedEvent = StoredEvent(
                eventId: eventId,
                aggregateId: aggregateId,
                eventType: eventType,
                eventData: eventData,
                timestamp: timestamp,
                deviceId: deviceId,
                version: version
            )
            
            events.append(storedEvent)
        }
        
        return events
    }
}

// MARK: - Supporting Types

/// Represents a stored event with metadata
public struct StoredEvent {
    public let eventId: UUID
    public let aggregateId: UUID
    public let eventType: String
    public let eventData: Data
    public let timestamp: Date
    public let deviceId: DeviceID
    public let version: Int
    
    /// Decode the event data to a specific event type
    public func decode<T: DomainEvent>(as type: T.Type) throws -> T {
        return try JSONDecoder().decode(type, from: eventData)
    }
}

/// Event stream for processing events in batches
public class EventStream {
    private let eventStore: EventStore
    private let batchSize: Int
    private var currentOffset: Int = 0
    
    init(eventStore: EventStore, batchSize: Int) {
        self.eventStore = eventStore
        self.batchSize = batchSize
    }
    
    /// Get the next batch of events
    public func nextBatch() throws -> [StoredEvent] {
        let sql = """
            SELECT event_id, aggregate_id, event_type, event_data, 
                   timestamp, device_id, version
            FROM crdt_events 
            ORDER BY timestamp ASC 
            LIMIT ? OFFSET ?;
        """
        
        let events = try eventStore.fetchEvents(sql: sql, parameters: [batchSize, currentOffset])
        currentOffset += events.count
        
        return events
    }
    
    /// Reset the stream to the beginning
    public func reset() {
        currentOffset = 0
    }
} 