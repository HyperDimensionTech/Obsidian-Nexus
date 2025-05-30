import Foundation
import SQLite3

class DatabaseManager {
    static let shared = DatabaseManager()
    private let currentVersion = 3
    
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
        
        do {
            let fileURL = try fileManager
                .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("obsidian_nexus.sqlite")
            
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
                print("🔹 DATABASE 🔹 Creating new database...")
                createTables()
            } else {
                print("🔹 DATABASE 🔹 Using existing database")
                migrateIfNeeded()
                
                // Verify database has tables
                let tableCount = executeScalar("SELECT count(*) FROM sqlite_master WHERE type='table';")
                print("🔹 DATABASE 🔹 Found \(tableCount) tables")
                
                // Count items
                let itemCount = executeScalar("SELECT count(*) FROM items WHERE deleted_at IS NULL;")
                print("🔹 DATABASE 🔹 Found \(itemCount) items")
            }
        } catch {
            print("🔹 DATABASE 🔹 CRITICAL ERROR: Failed to get documents directory: \(error.localizedDescription)")
            print("🔹 DATABASE 🔹 App will continue but database functionality may be limited")
        }
    }
    
    private func createTables() {
        // Create tables in correct order
        do {
            try createMetadataTable()
            
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
                    serial_number TEXT,
                    model_number TEXT,
                    character TEXT,
                    franchise TEXT,
                    dimensions TEXT,
                    weight TEXT,
                    release_date INTEGER,
                    limited_edition_number TEXT,
                    has_original_packaging INTEGER,
                    platform TEXT,
                    developer TEXT,
                    genre TEXT,
                    age_rating TEXT,
                    technical_specs TEXT,
                    warranty_expiry INTEGER,
                    FOREIGN KEY (location_id) REFERENCES locations(id),
                    UNIQUE(series, volume, deleted_at) WHERE deleted_at IS NULL
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
            
            let createISBNMappingsTable = """
                CREATE TABLE IF NOT EXISTS isbn_mappings (
                    incorrect_isbn TEXT PRIMARY KEY,
                    google_books_id TEXT NOT NULL,
                    title TEXT NOT NULL,
                    is_reprint INTEGER NOT NULL DEFAULT 1,
                    date_added INTEGER NOT NULL
                );
            """
            
            let createAttachmentsTable = """
                CREATE TABLE IF NOT EXISTS attachments (
                  id TEXT PRIMARY KEY,
                  item_id TEXT NOT NULL,
                  attachment_type TEXT NOT NULL,
                  file_name TEXT NOT NULL,
                  mime_type TEXT NOT NULL,
                  file_data BLOB NOT NULL,
                  created_at INTEGER NOT NULL,
                  FOREIGN KEY(item_id) REFERENCES items(id) ON DELETE CASCADE
                );
            """
            
            let createItemImagesTable = """
                CREATE TABLE IF NOT EXISTS item_images (
                  id TEXT PRIMARY KEY,
                  item_id TEXT NOT NULL,
                  image_type TEXT NOT NULL,
                  image_data BLOB NOT NULL,
                  created_at INTEGER NOT NULL,
                  FOREIGN KEY(item_id) REFERENCES items(id) ON DELETE CASCADE
                );
            """
            
            let createCategoriesTable = """
                CREATE TABLE IF NOT EXISTS categories (
                  id TEXT PRIMARY KEY,
                  parent_id TEXT,
                  name TEXT NOT NULL,
                  type TEXT NOT NULL,
                  created_at INTEGER NOT NULL,
                  FOREIGN KEY(parent_id) REFERENCES categories(id)
                );
            """
            
            let createItemCategoriesTable = """
                CREATE TABLE IF NOT EXISTS item_categories (
                  item_id TEXT NOT NULL,
                  category_id TEXT NOT NULL,
                  PRIMARY KEY(item_id, category_id),
                  FOREIGN KEY(item_id) REFERENCES items(id) ON DELETE CASCADE,
                  FOREIGN KEY(category_id) REFERENCES categories(id) ON DELETE CASCADE
                );
            """
            
            // Execute in correct order with error handling
            try beginTransaction()
            
            try executeStatement(createLocationsTable)
            try executeStatement(createItemsTable)
            try executeStatement(createCustomFieldsTable)
            try executeStatement(createClassificationRulesTable)
            try executeStatement(createISBNMappingsTable)
            try executeStatement(createAttachmentsTable)
            try executeStatement(createItemImagesTable)
            try executeStatement(createCategoriesTable)
            try executeStatement(createItemCategoriesTable)
            
            // Create indexes
            let createIndexes = [
                "CREATE INDEX IF NOT EXISTS idx_items_type ON items(type);",
                "CREATE INDEX IF NOT EXISTS idx_items_series ON items(series);",
                "CREATE INDEX IF NOT EXISTS idx_items_location ON items(location_id);",
                "CREATE INDEX IF NOT EXISTS idx_locations_parent ON locations(parent_id);",
                "CREATE INDEX IF NOT EXISTS idx_custom_fields_item ON custom_fields(item_id);",
                "CREATE INDEX IF NOT EXISTS idx_isbn_mappings_isbn ON isbn_mappings(incorrect_isbn);",
                "CREATE INDEX IF NOT EXISTS idx_items_serial_number ON items(serial_number);",
                "CREATE INDEX IF NOT EXISTS idx_items_model_number ON items(model_number);",
                "CREATE INDEX IF NOT EXISTS idx_items_franchise ON items(franchise);",
                "CREATE INDEX IF NOT EXISTS idx_items_platform ON items(platform);",
                "CREATE INDEX IF NOT EXISTS idx_attachments_item_id ON attachments(item_id);",
                "CREATE INDEX IF NOT EXISTS idx_item_images_item_id ON item_images(item_id);",
                "CREATE INDEX IF NOT EXISTS idx_categories_parent_id ON categories(parent_id);",
                "CREATE INDEX IF NOT EXISTS idx_categories_type ON categories(type);"
            ]
            
            for index in createIndexes {
                try executeStatement(index)
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
                
                let parameters = Array(repeating: timestamp, count: 32) // 16 rules * 2 timestamps each
                try executeStatement(initialRules, parameters: parameters)
            }
            
            try commitTransaction()
        } catch {
            try? rollbackTransaction()
            print("Error creating tables: \(error.localizedDescription)")
        }
    }
    
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
    
    private func migrateIfNeeded() {
        let currentDBVersion = getDatabaseVersion()
        
        if currentDBVersion < currentVersion {
            print("Migrating database from v\(currentDBVersion) to v\(currentVersion)")
            
            // Perform incremental migrations
            if currentDBVersion < 1 {
                migrateToV1()
            }

            // Add migration for isbn_mappings table
            if currentDBVersion < 2 {
                migrateToV2()
            }
            
            // Add migration for expanded item fields and new tables
            if currentDBVersion < 3 {
                migrateToV3()
            }
            
            // Set the new version
            do {
                try setDatabaseVersion(currentVersion)
            } catch {
                print("🔹 DATABASE 🔹 Error setting database version: \(error.localizedDescription)")
                // Consider if we need to handle this error more robustly
                // For now, we log it but the app can continue since the schema updates were applied
            }
        }
    }
    
    private func migrateToV1() {
        // v1 migration is handled by initial setup
    }
    
    private func migrateToV2() {
        do {
            // Create isbn_mappings table
            let createISBNMappingsTable = """
                CREATE TABLE IF NOT EXISTS isbn_mappings (
                    incorrect_isbn TEXT PRIMARY KEY,
                    google_books_id TEXT NOT NULL,
                    title TEXT NOT NULL,
                    is_reprint INTEGER NOT NULL DEFAULT 1,
                    date_added INTEGER NOT NULL
                );
            """
            try executeStatement(createISBNMappingsTable)
            
            // Create index for performance
            let createISBNIndex = """
                CREATE INDEX IF NOT EXISTS idx_isbn_mappings_isbn
                ON isbn_mappings (incorrect_isbn);
            """
            try executeStatement(createISBNIndex)
        } catch {
            print("Error migrating to V2: \(error.localizedDescription)")
        }
    }
    
    private func migrateToV3() {
        do {
            print("🔹 DATABASE 🔹 Starting migration to V3...")
            
            try beginTransaction()
            
            // Add new columns to items table
            let alterItemsSQL = [
                "ALTER TABLE items ADD COLUMN serial_number TEXT;",
                "ALTER TABLE items ADD COLUMN model_number TEXT;",
                "ALTER TABLE items ADD COLUMN character TEXT;",
                "ALTER TABLE items ADD COLUMN franchise TEXT;",
                "ALTER TABLE items ADD COLUMN dimensions TEXT;",
                "ALTER TABLE items ADD COLUMN weight TEXT;",
                "ALTER TABLE items ADD COLUMN release_date INTEGER;",
                "ALTER TABLE items ADD COLUMN limited_edition_number TEXT;",
                "ALTER TABLE items ADD COLUMN has_original_packaging INTEGER;",
                "ALTER TABLE items ADD COLUMN platform TEXT;",
                "ALTER TABLE items ADD COLUMN developer TEXT;",
                "ALTER TABLE items ADD COLUMN genre TEXT;",
                "ALTER TABLE items ADD COLUMN age_rating TEXT;",
                "ALTER TABLE items ADD COLUMN technical_specs TEXT;",
                "ALTER TABLE items ADD COLUMN warranty_expiry INTEGER;"
            ]
            
            for sql in alterItemsSQL {
                try executeStatement(sql)
            }
            
            // Create attachments table
            let createAttachmentsTable = """
                CREATE TABLE IF NOT EXISTS attachments (
                  id TEXT PRIMARY KEY,
                  item_id TEXT NOT NULL,
                  attachment_type TEXT NOT NULL,
                  file_name TEXT NOT NULL,
                  mime_type TEXT NOT NULL,
                  file_data BLOB NOT NULL,
                  created_at INTEGER NOT NULL,
                  FOREIGN KEY(item_id) REFERENCES items(id) ON DELETE CASCADE
                );
            """
            try executeStatement(createAttachmentsTable)
            
            // Create additional images table
            let createItemImagesTable = """
                CREATE TABLE IF NOT EXISTS item_images (
                  id TEXT PRIMARY KEY,
                  item_id TEXT NOT NULL,
                  image_type TEXT NOT NULL,
                  image_data BLOB NOT NULL,
                  created_at INTEGER NOT NULL,
                  FOREIGN KEY(item_id) REFERENCES items(id) ON DELETE CASCADE
                );
            """
            try executeStatement(createItemImagesTable)
            
            // Create categories table
            let createCategoriesTable = """
                CREATE TABLE IF NOT EXISTS categories (
                  id TEXT PRIMARY KEY,
                  parent_id TEXT,
                  name TEXT NOT NULL,
                  type TEXT NOT NULL,
                  created_at INTEGER NOT NULL,
                  FOREIGN KEY(parent_id) REFERENCES categories(id)
                );
            """
            try executeStatement(createCategoriesTable)
            
            // Create item_categories table
            let createItemCategoriesTable = """
                CREATE TABLE IF NOT EXISTS item_categories (
                  item_id TEXT NOT NULL,
                  category_id TEXT NOT NULL,
                  PRIMARY KEY(item_id, category_id),
                  FOREIGN KEY(item_id) REFERENCES items(id) ON DELETE CASCADE,
                  FOREIGN KEY(category_id) REFERENCES categories(id) ON DELETE CASCADE
                );
            """
            try executeStatement(createItemCategoriesTable)
            
            // Add indexes for performance
            let createIndexes = [
                "CREATE INDEX IF NOT EXISTS idx_items_serial_number ON items(serial_number);",
                "CREATE INDEX IF NOT EXISTS idx_items_model_number ON items(model_number);",
                "CREATE INDEX IF NOT EXISTS idx_items_franchise ON items(franchise);",
                "CREATE INDEX IF NOT EXISTS idx_items_platform ON items(platform);",
                "CREATE INDEX IF NOT EXISTS idx_attachments_item_id ON attachments(item_id);",
                "CREATE INDEX IF NOT EXISTS idx_item_images_item_id ON item_images(item_id);",
                "CREATE INDEX IF NOT EXISTS idx_categories_parent_id ON categories(parent_id);",
                "CREATE INDEX IF NOT EXISTS idx_categories_type ON categories(type);"
            ]
            
            for sql in createIndexes {
                try executeStatement(sql)
            }
            
            try commitTransaction()
            print("🔹 DATABASE 🔹 Successfully migrated to V3")
            
        } catch {
            do {
                try rollbackTransaction()
            } catch {
                print("🔹 DATABASE 🔹 Error rolling back transaction: \(error.localizedDescription)")
            }
            print("🔹 DATABASE 🔹 Error migrating to V3: \(error.localizedDescription)")
        }
    }
    
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