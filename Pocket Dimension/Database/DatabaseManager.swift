import Foundation
import SQLite3

public class DatabaseManager {
    public static let shared = DatabaseManager()
    private let currentVersion = DatabaseSchema.crdtVersion // CRDT-only system
    
    private(set) var connection: OpaquePointer?
    
    public enum DatabaseError: LocalizedError {
        case connectionFailed
        case queryFailed(String)
        case prepareFailed(String)
        case invalidData
        case insertFailed
        case updateFailed
        case deleteFailed
        case notFound
        case transactionFailed(String)
        case constraintViolation(String)
        case deadlock
        case diskFull
        case notImplemented
        
        public var errorDescription: String? {
            switch self {
            case .connectionFailed:
                return "Failed to connect to the database"
            case .queryFailed(let message):
                return "Database query failed: \(message)"
            case .prepareFailed(let message):
                return "Failed to prepare statement: \(message)"
            case .invalidData:
                return "Invalid data format encountered"
            case .insertFailed:
                return "Failed to insert item into database"
            case .updateFailed:
                return "Failed to update item in database"
            case .deleteFailed:
                return "Failed to delete item from database"
            case .notFound:
                return "Item not found in database"
            case .transactionFailed(let message):
                return "Transaction failed: \(message)"
            case .constraintViolation(let constraint):
                return "Constraint violation: \(constraint)"
            case .deadlock:
                return "Deadlock detected"
            case .diskFull:
                return "Disk is full"
            case .notImplemented:
                return "Feature not yet implemented"
            }
        }
    }
    
    init() {
        setupDatabase()
    }
    
    private func setupDatabase() {
        let fileManager = FileManager.default
        
        do {
            let fileURL = try fileManager
                .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("pocket_dimension.sqlite")
            
            print("🔹 DATABASE 🔹 Path: \(fileURL.path)")
            
            let fileExists = fileManager.fileExists(atPath: fileURL.path)
            print("🔹 DATABASE 🔹 File exists: \(fileExists)")
            
            // Check if file is readable
            if fileExists {
                let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path)
                print("🔹 DATABASE 🔹 File size: \(attributes?[.size] as? Int ?? 0) bytes")
                print("🔹 DATABASE 🔹 File permissions: \(attributes?[.posixPermissions] as? Int ?? 0)")
            }
            
            let needsSetup = !fileExists
            
            if sqlite3_open(fileURL.path, &connection) != SQLITE_OK {
                let errorMsg = String(cString: sqlite3_errmsg(connection))
                print("🔹 DATABASE 🔹 Error opening database: \(errorMsg)")
                return
            }
            
            print("🔹 DATABASE 🔹 Successfully opened connection")
            
            // Enable foreign keys
            do {
                try executeStatement("PRAGMA foreign_keys = ON;")
            } catch {
                print("🔹 DATABASE 🔹 Error enabling foreign keys: \(error.localizedDescription)")
            }
            
            // Set WAL mode with proper error handling
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(connection, "PRAGMA journal_mode = WAL;", -1, &statement, nil) == SQLITE_OK {
                if sqlite3_step(statement) == SQLITE_ROW {
                    let journalMode = sqlite3_column_text(statement, 0).map { String(cString: $0) } ?? "unknown"
                    print("🔹 DATABASE 🔹 Journal mode set to: \(journalMode)")
                    sqlite3_finalize(statement)
                }
            }
            
            if needsSetup {
                print("🔹 DATABASE 🔹 Creating new database with CRDT schema...")
                try setupNewCRDTDatabase()
            } else {
                print("🔹 DATABASE 🔹 Using existing database")
                try migrateToNewSchemaIfNeeded()
                
                // Verify database has tables
                let tableCount = executeScalar("SELECT count(*) FROM sqlite_master WHERE type='table';")
                print("🔹 DATABASE 🔹 Found \(tableCount) tables")
                
                // Count items in new or legacy format
                let itemCount = getCurrentItemCount()
                print("🔹 DATABASE 🔹 Found \(itemCount) items")
            }
        } catch {
            print("🔹 DATABASE 🔹 CRITICAL ERROR: Failed to get documents directory: \(error.localizedDescription)")
            print("🔹 DATABASE 🔹 App will continue but database functionality may be limited")
        }
    }
    
    // MARK: - CRDT Database Setup
    
    private func setupNewCRDTDatabase() throws {
        print("🔹 DATABASE 🔹 Setting up CRDT-only database...")
        
        // Create metadata table first
        try createMetadataTable()
        
        // Create CRDT tables only
        try DatabaseSchema.createCRDTSchema(database: self)
        
        print("🔹 DATABASE 🔹 CRDT tables created")
        
        // Update schema version
        try setUserVersion(DatabaseSchema.crdtVersion)
        
        print("🔹 DATABASE 🔹 CRDT-only database setup complete")
    }
    
    // Legacy table creation removed - using CRDT only
    
    private func migrateToNewSchemaIfNeeded() throws {
        let currentSchemaVersion = getUserVersion()
        print("🔹 DATABASE 🔹 Current schema version: \(currentSchemaVersion)")
        
        if currentSchemaVersion < DatabaseSchema.crdtVersion {
            print("🔹 DATABASE 🔹 Migration needed: v\(currentSchemaVersion) -> v\(DatabaseSchema.crdtVersion)")
            try performMigrationToCRDT(fromVersion: currentSchemaVersion)
        } else {
            print("🔹 DATABASE 🔹 Schema is up to date")
            
            // Validate that all required tables exist, even if schema version is correct
            try validateAndCreateMissingTables()
        }
    }
    
    private func performMigrationToCRDT(fromVersion: Int) throws {
        print("🔹 DATABASE 🔹 Starting migration from version \(fromVersion) to CRDT-only")
        
        // Set migration status
        try setMigrationStatus(.inProgress)
        
        do {
            // Step 1: Create CRDT tables only
            try DatabaseSchema.createCRDTSchema(database: self)
            
            // Step 2: Export existing data for migration (if any legacy data exists)
            let exportedData = try exportLegacyData()
            print("🔹 DATABASE 🔹 Exported \(exportedData.items.count) items and \(exportedData.locations.count) locations")
            
            // Step 3: Convert to events and import
            if !exportedData.isEmpty {
                try importDataAsEvents(exportedData)
                print("🔹 DATABASE 🔹 Successfully migrated data to CRDT system")
            }
            
            // Step 4: Update schema version
            try setUserVersion(DatabaseSchema.crdtVersion)
            
            // Step 5: Mark migration complete
            try setMigrationStatus(.completed)
            
            print("🔹 DATABASE 🔹 Migration to CRDT-only completed successfully")
            
        } catch {
            print("🔹 DATABASE 🔹 Migration failed: \(error)")
            try setMigrationStatus(.failed)
            throw error
        }
    }
    
    // Legacy table validation removed - using CRDT only
    
    private func validateAndCreateMissingTables() throws {
        print("🔹 DATABASE 🔹 Validating CRDT tables exist...")
        
        // Check CRDT tables only
        let requiredCRDTTables = ["crdt_events", "device_metadata", "sync_state"]
        var missingCRDTTables: [String] = []
        
        for table in requiredCRDTTables {
            let count = executeScalar("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='\(table)';")
            if count == 0 {
                missingCRDTTables.append(table)
            }
        }
        
        if !missingCRDTTables.isEmpty {
            print("🔹 DATABASE 🔹 Missing CRDT tables: \(missingCRDTTables.joined(separator: ", "))")
            print("🔹 DATABASE 🔹 Creating missing CRDT tables...")
            
            // Create missing CRDT tables
            try DatabaseSchema.createCRDTSchema(database: self)
            
            print("🔹 DATABASE 🔹 CRDT tables created successfully")
        } else {
            print("🔹 DATABASE 🔹 All required CRDT tables exist")
        }
    }
    
    private func getCurrentItemCount() -> Int64 {
        // Count unique items from CRDT events (created minus deleted)
        let createdCount = executeScalar("SELECT COUNT(DISTINCT aggregate_id) FROM crdt_events WHERE aggregate_type = 'InventoryItem' AND event_type LIKE '%Created%';")
        let deletedCount = executeScalar("SELECT COUNT(DISTINCT aggregate_id) FROM crdt_events WHERE aggregate_type = 'InventoryItem' AND event_type LIKE '%Deleted%';")
        
        return Int64(max(0, createdCount - deletedCount))
    }
    
    // MARK: - Migration Helpers
    
    private func setUserVersion(_ version: Int) throws {
        let sql = "PRAGMA user_version = \(version);"
        try executeStatement(sql)
    }
    
    private func getUserVersion() -> Int {
        let sql = "PRAGMA user_version;"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(connection, sql, -1, &statement, nil) == SQLITE_OK else {
            return 0
        }
        
        defer { sqlite3_finalize(statement) }
        
        if sqlite3_step(statement) == SQLITE_ROW {
            return Int(sqlite3_column_int(statement, 0))
        }
        
        return 0
    }
    
    private func setMigrationStatus(_ status: MigrationStatus) throws {
        let sql = "INSERT OR REPLACE INTO sync_state (key, value) VALUES ('migration_status', ?);"
        try executeStatement(sql, parameters: [status.rawValue])
    }
    
    private func getMigrationStatus() -> MigrationStatus {
        let sql = "SELECT value FROM sync_state WHERE key = 'migration_status';"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(connection, sql, -1, &statement, nil) == SQLITE_OK else {
            return .pending
        }
        
        defer { sqlite3_finalize(statement) }
        
        if sqlite3_step(statement) == SQLITE_ROW {
            let statusString = String(cString: sqlite3_column_text(statement, 0))
            return MigrationStatus(rawValue: statusString) ?? .pending
        }
        
        return .pending
    }
    
    // Legacy table creation removed - using CRDT-only system
    
    private func createMetadataTable() throws {
        let sql = """
            CREATE TABLE IF NOT EXISTS metadata (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );
        """
        try executeStatement(sql)
        
        // Set initial version if not exists
        let version = getDatabaseVersion()
        if version == 0 {
            try setDatabaseVersion(1)
        }
    }
    
    private func getDatabaseVersion() -> Int {
        let sql = "SELECT value FROM metadata WHERE key = 'version';"
        var statement: OpaquePointer?
        var version = 0
        
        if sqlite3_prepare_v2(connection, sql, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                if let versionString = sqlite3_column_text(statement, 0) {
                    version = Int(String(cString: versionString)) ?? 0
                }
            }
        }
        sqlite3_finalize(statement)
        return version
    }
    
    private func setDatabaseVersion(_ version: Int) throws {
        let sql = """
            INSERT OR REPLACE INTO metadata (key, value)
            VALUES ('version', ?);
        """
        try executeStatement(sql, parameters: [String(version)])
    }
    
    // Legacy migration methods removed - using CRDT-only system
    
    func executeStatement(_ sql: String, parameters: [Any] = []) throws {
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(connection, sql, -1, &statement, nil) == SQLITE_OK else {
            let error = String(cString: sqlite3_errmsg(connection))
            throw DatabaseError.prepareFailed(error)
        }
        
        defer {
            sqlite3_finalize(statement)
        }
        
        for (index, param) in parameters.enumerated() {
            let idx = Int32(index + 1)
            
            switch param {
            case let text as String:
                if sqlite3_bind_text(statement, idx, (text as NSString).utf8String, -1, nil) != SQLITE_OK {
                    throw DatabaseError.invalidData
                }
            case let int as Int:
                if sqlite3_bind_int64(statement, idx, Int64(int)) != SQLITE_OK {
                    throw DatabaseError.invalidData
                }
            case let double as Double:
                if sqlite3_bind_double(statement, idx, double) != SQLITE_OK {
                    throw DatabaseError.invalidData
                }
            case let data as Data:
                let result = data.withUnsafeBytes { bytes in
                    sqlite3_bind_blob(statement, idx, bytes.baseAddress, Int32(data.count), nil)
                }
                if result != SQLITE_OK {
                    throw DatabaseError.invalidData
                }
            case is NSNull:
                if sqlite3_bind_null(statement, idx) != SQLITE_OK {
                    throw DatabaseError.invalidData
                }
            default:
                throw DatabaseError.invalidData
            }
        }
        
        let result = sqlite3_step(statement)
        switch result {
        case SQLITE_DONE:
            return
        case SQLITE_CONSTRAINT:
            let error = String(cString: sqlite3_errmsg(connection))
            if error.contains("UNIQUE") {
                // Extract the conflicting values from the error message
                if error.contains("series") && error.contains("volume") {
                    throw DatabaseError.constraintViolation("This volume already exists in the series")
                } else {
                    throw DatabaseError.constraintViolation(error)
                }
            } else {
                throw DatabaseError.constraintViolation(error)
            }
        case SQLITE_BUSY:
            throw DatabaseError.deadlock
        case SQLITE_FULL:
            throw DatabaseError.diskFull
        default:
            let error = String(cString: sqlite3_errmsg(connection))
            throw DatabaseError.queryFailed(error)
        }
    }
    
    func beginTransaction() throws {
        try executeStatement("BEGIN TRANSACTION;")
    }
    
    func commitTransaction() throws {
        try executeStatement("COMMIT;")
    }
    
    func rollbackTransaction() throws {
        try executeStatement("ROLLBACK;")
    }
    
    func executeScalar(_ sql: String) -> Int {
        var statement: OpaquePointer?
        var result: Int64 = 0
        
        guard sqlite3_prepare_v2(connection, sql, -1, &statement, nil) == SQLITE_OK else {
            print("Error preparing scalar query: \(String(cString: sqlite3_errmsg(connection)))")
            return 0
        }
        
        defer {
            sqlite3_finalize(statement)
        }
        
        if sqlite3_step(statement) == SQLITE_ROW {
            result = sqlite3_column_int64(statement, 0)
        }
        
        return Int(result)
    }
    
    func closeConnection() {
        if connection != nil {
            sqlite3_close(connection)
            connection = nil
        }
    }
    
    func reopenConnection() {
        setupDatabase()
    }
    
    deinit {
        closeConnection()
    }
} 