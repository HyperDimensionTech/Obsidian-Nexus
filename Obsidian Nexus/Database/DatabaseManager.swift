import Foundation
import SQLite3

class DatabaseManager {
    static let shared = DatabaseManager()
    private let currentVersion = 1
    
    private(set) var connection: OpaquePointer?
    
    enum DatabaseError: LocalizedError {
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
        
        var errorDescription: String? {
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
            }
        }
    }
    
    init() {
        setupDatabase()
    }
    
    private func setupDatabase() {
        let fileManager = FileManager.default
        let fileURL = try! fileManager
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("obsidian_nexus.sqlite")
        
        print("Database path: \(fileURL.path)")
        
        let needsSetup = !fileManager.fileExists(atPath: fileURL.path)
        
        if sqlite3_open(fileURL.path, &connection) != SQLITE_OK {
            print("Error opening database: \(String(cString: sqlite3_errmsg(connection)))")
            return
        }
        
        // Enable foreign keys
        executeStatement("PRAGMA foreign_keys = ON;")
        
        // Set WAL mode with proper error handling
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(connection, "PRAGMA journal_mode = WAL;", -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                // WAL mode set successfully
                sqlite3_finalize(statement)
            }
        }
        
        if needsSetup {
            print("Creating new database...")
            createTables()
        } else {
            print("Using existing database")
            migrateIfNeeded()
        }
    }
    
    private func createTables() {
        // Create tables in correct order
        createMetadataTable()
        
        // Create core tables
        let createLocationsTable = """
            CREATE TABLE IF NOT EXISTS locations (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                type TEXT NOT NULL,
                parent_id TEXT,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                deleted_at INTEGER,
                FOREIGN KEY (parent_id) REFERENCES locations (id)
            );
        """
        
        let createItemsTable = """
            CREATE TABLE IF NOT EXISTS items (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                type TEXT NOT NULL,
                series TEXT,
                volume INTEGER,
                condition TEXT NOT NULL,
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
                image_source TEXT,
                FOREIGN KEY (location_id) REFERENCES locations(id)
            );
        """
        
        let createCustomFieldsTable = """
            CREATE TABLE IF NOT EXISTS custom_fields (
                id TEXT PRIMARY KEY,
                item_id TEXT NOT NULL,
                key TEXT NOT NULL,
                value TEXT,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                FOREIGN KEY(item_id) REFERENCES items(id) ON DELETE CASCADE,
                UNIQUE(item_id, key)
            );
        """
        
        let createClassificationRulesTable = """
            CREATE TABLE IF NOT EXISTS classification_rules (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                pattern TEXT NOT NULL,
                pattern_type TEXT NOT NULL,
                priority INTEGER NOT NULL,
                media_type TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
            );
        """
        
        // Execute in correct order with error handling
        do {
            try beginTransaction()
            
            executeStatement(createLocationsTable)
            executeStatement(createItemsTable)
            executeStatement(createCustomFieldsTable)
            executeStatement(createClassificationRulesTable)
            
            // Create indexes
            let createIndexes = [
                "CREATE INDEX IF NOT EXISTS idx_items_type ON items(type);",
                "CREATE INDEX IF NOT EXISTS idx_items_series ON items(series);",
                "CREATE INDEX IF NOT EXISTS idx_items_location ON items(location_id);",
                "CREATE INDEX IF NOT EXISTS idx_locations_parent ON locations(parent_id);",
                "CREATE INDEX IF NOT EXISTS idx_custom_fields_item ON custom_fields(item_id);"
            ]
            
            for index in createIndexes {
                executeStatement(index)
            }
            
            // Add initial rules if table is empty
            let checkRules = "SELECT COUNT(*) FROM classification_rules;"
            if executeScalar(checkRules) == 0 {
                let timestamp = Int(Date().timeIntervalSince1970)
                let initialRules = """
                    INSERT INTO classification_rules 
                    (pattern, pattern_type, priority, media_type, created_at, updated_at)
                    VALUES 
                    ('viz media', 'publisher', 1, 'manga', ?, ?),
                    ('viz', 'publisher', 1, 'manga', ?, ?),
                    ('kodansha', 'publisher', 1, 'manga', ?, ?),
                    ('seven seas', 'publisher', 1, 'manga', ?, ?),
                    ('yen press', 'publisher', 1, 'manga', ?, ?),
                    ('shogakukan', 'publisher', 1, 'manga', ?, ?),
                    ('shueisha', 'publisher', 1, 'manga', ?, ?),
                    ('manga', 'title', 2, 'manga', ?, ?),
                    ('vol.', 'title', 2, 'manga', ?, ?),
                    ('volume', 'title', 2, 'manga', ?, ?),
                    ('marvel', 'publisher', 1, 'comics', ?, ?),
                    ('dc comics', 'publisher', 1, 'comics', ?, ?),
                    ('image comics', 'publisher', 1, 'comics', ?, ?),
                    ('dark horse', 'publisher', 1, 'comics', ?, ?),
                    ('comic', 'title', 2, 'comics', ?, ?),
                    ('graphic novel', 'title', 2, 'comics', ?, ?);
                """
                
                let parameters = Array(repeating: timestamp, count: 18) // 9 rules * 2 timestamps each
                executeStatement(initialRules, parameters: parameters)
            }
            
            try commitTransaction()
        } catch {
            try? rollbackTransaction()
            print("Error creating tables: \(error.localizedDescription)")
        }
    }
    
    private func createMetadataTable() {
        let sql = """
            CREATE TABLE IF NOT EXISTS metadata (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );
        """
        executeStatement(sql)
        
        // Set initial version if not exists
        let version = getDatabaseVersion()
        if version == 0 {
            setDatabaseVersion(1)
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
    
    private func setDatabaseVersion(_ version: Int) {
        let sql = """
            INSERT OR REPLACE INTO metadata (key, value)
            VALUES ('version', ?);
        """
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(connection, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, String(version).cString(using: .utf8), -1, nil)
            if sqlite3_step(statement) != SQLITE_DONE {
                print("Error setting database version")
            }
        }
        sqlite3_finalize(statement)
    }
    
    private func migrateIfNeeded() {
        let version = getDatabaseVersion()
        if version < currentVersion {
            // Add migration for image columns
            let migrations = [
                "ALTER TABLE items ADD COLUMN custom_image_data BLOB;",
                "ALTER TABLE items ADD COLUMN image_source TEXT;"
            ]
            
            for migration in migrations {
                executeStatement(migration)
            }
            
            setDatabaseVersion(currentVersion)
        }
    }
    
    func executeStatement(_ sql: String, parameters: [Any] = []) {
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(connection, sql, -1, &statement, nil) == SQLITE_OK else {
            let error = String(cString: sqlite3_errmsg(connection))
            print("Error preparing statement: \(error)")
            return
        }
        
        defer {
            sqlite3_finalize(statement)
        }
        
        for (index, param) in parameters.enumerated() {
            let idx = Int32(index + 1)
            
            switch param {
            case let text as String:
                sqlite3_bind_text(statement, idx, (text as NSString).utf8String, -1, nil)
            case let int as Int:
                sqlite3_bind_int64(statement, idx, Int64(int))
            case let data as Data:
                _ = data.withUnsafeBytes { bytes in
                    sqlite3_bind_blob(statement, idx, bytes.baseAddress, Int32(data.count), nil)
                }
            case is NSNull:
                sqlite3_bind_null(statement, idx)
            default:
                print("Unsupported parameter type: \(type(of: param))")
                continue
            }
        }
        
        if sqlite3_step(statement) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(connection))
            print("Error executing statement: \(sql)")
            print("SQLite error: \(error)")
        }
    }
    
    func beginTransaction() throws {
        executeStatement("BEGIN TRANSACTION;")
    }
    
    func commitTransaction() throws {
        executeStatement("COMMIT;")
    }
    
    func rollbackTransaction() throws {
        executeStatement("ROLLBACK;")
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
    
    deinit {
        if connection != nil {
            sqlite3_close(connection)
            connection = nil
        }
    }
} 