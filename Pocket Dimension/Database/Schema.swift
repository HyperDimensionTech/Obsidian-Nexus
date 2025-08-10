import Foundation
import SQLite3
#if os(iOS)
import UIKit
#elseif os(macOS)
import Foundation
#endif

public class DatabaseSchema {
    
    // MARK: - Schema Versions
    public static let legacyVersion = 3 // Current/legacy schema
    public static let crdtVersion = 4   // New CRDT-enabled schema
    
    // MARK: - Legacy Schema (v3) - Keep for migration
    public static let legacyTables = [
        // Existing inventory_items table (renamed to items for compatibility)
        """
        CREATE TABLE IF NOT EXISTS items (
            id TEXT PRIMARY KEY,
            user_id TEXT,
            title TEXT NOT NULL,
            type TEXT NOT NULL DEFAULT 'books',
            series TEXT,
            volume INTEGER,
            condition TEXT NOT NULL DEFAULT 'good',
            location_id TEXT,
            notes TEXT,
            date_added INTEGER NOT NULL,
            barcode TEXT,
            thumbnail_url TEXT,
            author TEXT,
            manufacturer TEXT,
            original_publish_date INTEGER,
            publisher TEXT,
            isbn TEXT,
            price REAL,
            purchase_date INTEGER,
            synopsis TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            deleted_at INTEGER,
            custom_image_data BLOB,
            image_source TEXT DEFAULT 'none',
            serial_number TEXT,
            model_number TEXT,
            character TEXT,
            franchise TEXT,
            dimensions TEXT,
            weight REAL,
            release_date INTEGER,
            limited_edition_number INTEGER,
            has_original_packaging INTEGER,
            platform TEXT,
            developer TEXT,
            genre TEXT,
            age_rating TEXT,
            technical_specs TEXT,
            warranty_expiry INTEGER,
            FOREIGN KEY (location_id) REFERENCES storage_locations(id) ON DELETE SET NULL
        );
        """,
        
        // Existing storage_locations table
        """
        CREATE TABLE IF NOT EXISTS storage_locations (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            type TEXT NOT NULL DEFAULT 'room',
            parent_id TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            deleted_at INTEGER,
            FOREIGN KEY (parent_id) REFERENCES storage_locations(id) ON DELETE CASCADE
        );
        """,
        
        // Existing isbn_mappings table
        """
        CREATE TABLE IF NOT EXISTS isbn_mappings (
            incorrect_isbn TEXT PRIMARY KEY,
            google_books_id TEXT NOT NULL,
            title TEXT NOT NULL,
            is_reprint INTEGER NOT NULL DEFAULT 1,
            date_added INTEGER NOT NULL
        );
        """
    ]
    
    // MARK: - Enhanced CRDT Schema (v4)
    public static let crdtTables = [
        // Events table for event sourcing
        """
        CREATE TABLE IF NOT EXISTS crdt_events (
            event_id TEXT PRIMARY KEY,
            aggregate_id TEXT NOT NULL,
            aggregate_type TEXT NOT NULL,
            event_type TEXT NOT NULL,
            event_data BLOB NOT NULL,
            vector_clock TEXT NOT NULL,
            device_id TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            version INTEGER NOT NULL,
            created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
            UNIQUE(aggregate_id, version)
        );
        """,
        
        // Device metadata for sync coordination
        """
        CREATE TABLE IF NOT EXISTS device_metadata (
            device_id TEXT PRIMARY KEY,
            device_name TEXT NOT NULL,
            device_type TEXT NOT NULL, -- 'iphone', 'ipad', 'mac'
            last_sync_timestamp INTEGER,
            vector_clock TEXT NOT NULL,
            is_active BOOLEAN NOT NULL DEFAULT 1,
            created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
            updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
        );
        """,
        
        // Sync state management
        """
        CREATE TABLE IF NOT EXISTS sync_state (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
        );
        """,
        
        // Cloud sync metadata
        """
        CREATE TABLE IF NOT EXISTS cloud_sync_metadata (
            id TEXT PRIMARY KEY,
            cloud_provider TEXT NOT NULL, -- 'supabase', 'firebase', etc.
            cloud_record_id TEXT,
            last_cloud_sync INTEGER,
            sync_status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'synced', 'conflict', 'error'
            retry_count INTEGER NOT NULL DEFAULT 0,
            error_message TEXT,
            created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
            updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
        );
        """,
        
        // Local network sync metadata
        """
        CREATE TABLE IF NOT EXISTS local_sync_metadata (
            event_id TEXT PRIMARY KEY,
            sync_status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'synced', 'conflict', 'error'
            synced_at INTEGER,
            device_id TEXT NOT NULL,
            created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
            updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
        );
        """,
        
        // Vector clock state for CRDT
        """
        CREATE TABLE IF NOT EXISTS vector_clocks (
            device_id TEXT PRIMARY KEY,
            logical_clock INTEGER NOT NULL DEFAULT 0,
            last_updated INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
        );
        """,
        
        // Conflict resolution log
        """
        CREATE TABLE IF NOT EXISTS conflict_resolutions (
            id TEXT PRIMARY KEY,
            aggregate_id TEXT NOT NULL,
            conflict_type TEXT NOT NULL,
            local_event_id TEXT NOT NULL,
            remote_event_id TEXT NOT NULL,
            resolution_strategy TEXT NOT NULL,
            resolved_event_id TEXT NOT NULL,
            resolved_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
            FOREIGN KEY (local_event_id) REFERENCES crdt_events(event_id),
            FOREIGN KEY (remote_event_id) REFERENCES crdt_events(event_id),
            FOREIGN KEY (resolved_event_id) REFERENCES crdt_events(event_id)
        );
        """
    ]
    
    // MARK: - Indexes for Performance
    public static let crdtIndexes = [
        "CREATE INDEX IF NOT EXISTS idx_crdt_events_aggregate ON crdt_events(aggregate_id);",
        "CREATE INDEX IF NOT EXISTS idx_crdt_events_timestamp ON crdt_events(timestamp);",
        "CREATE INDEX IF NOT EXISTS idx_crdt_events_device ON crdt_events(device_id);",
        "CREATE INDEX IF NOT EXISTS idx_crdt_events_type ON crdt_events(event_type);",
        "CREATE INDEX IF NOT EXISTS idx_crdt_events_aggregate_type ON crdt_events(aggregate_type);",
        "CREATE INDEX IF NOT EXISTS idx_cloud_sync_status ON cloud_sync_metadata(sync_status);",
        "CREATE INDEX IF NOT EXISTS idx_local_sync_status ON local_sync_metadata(sync_status);",
        "CREATE INDEX IF NOT EXISTS idx_local_sync_device ON local_sync_metadata(device_id);",
        "CREATE INDEX IF NOT EXISTS idx_vector_clocks_device ON vector_clocks(device_id);",
        "CREATE INDEX IF NOT EXISTS idx_conflict_resolutions_aggregate ON conflict_resolutions(aggregate_id);"
    ]
    
    // MARK: - Migration Helpers
    public static func createLegacySchema(database: DatabaseManager) throws {
        for tableSQL in legacyTables {
            try database.executeStatement(tableSQL)
        }
    }
    
    public static func createCRDTSchema(database: DatabaseManager) throws {
        // Create CRDT tables
        for tableSQL in crdtTables {
            try database.executeStatement(tableSQL)
        }
        
        // Create indexes
        for indexSQL in crdtIndexes {
            try database.executeStatement(indexSQL)
        }
        
        // Initialize sync state
        try initializeSyncState(database: database)
    }
    
    private static func initializeSyncState(database: DatabaseManager) throws {
        let deviceId = DeviceID().uuid
        let deviceName = getCurrentDeviceName()
        let deviceType = getCurrentDeviceType()
        let timestamp = Int(Date().timeIntervalSince1970)
        
        // Insert device metadata
        let deviceSQL = """
            INSERT OR REPLACE INTO device_metadata 
            (device_id, device_name, device_type, vector_clock, created_at, updated_at)
            VALUES (?, ?, ?, '{}', ?, ?);
        """
        try database.executeStatement(deviceSQL, parameters: [
            deviceId, deviceName, deviceType, timestamp, timestamp
        ])
        
        // Initialize sync state
        let syncStateEntries = [
            ("current_device_id", deviceId),
            ("schema_version", "\(crdtVersion)"),
            ("migration_status", "completed"),
            ("last_full_sync", "0")
        ]
        
        for (key, value) in syncStateEntries {
            let syncSQL = "INSERT OR REPLACE INTO sync_state (key, value) VALUES (?, ?);"
            try database.executeStatement(syncSQL, parameters: [key, value])
        }
    }
    
    private static func getCurrentDeviceName() -> String {
        #if os(iOS)
        return UIDevice.current.name
        #elseif os(macOS)
        return Host.current().localizedName ?? "Mac"
        #else
        return "Unknown Device"
        #endif
    }
    
    private static func getCurrentDeviceType() -> String {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone"
        #elseif os(macOS)
        return "mac"
        #else
        return "unknown"
        #endif
    }
}

// MARK: - Migration Status
public enum MigrationStatus: String, CaseIterable {
    case pending = "pending"
    case inProgress = "in_progress"
    case completed = "completed"
    case failed = "failed"
    
    public var description: String {
        switch self {
        case .pending: return "Migration Pending"
        case .inProgress: return "Migration In Progress"
        case .completed: return "Migration Completed"
        case .failed: return "Migration Failed"
        }
    }
} 