import Foundation
import SQLite3

// Just use the type directly since we're in the same module
typealias ImageSource = InventoryItem.ImageSource

protocol ItemRepository {
    func save(_ item: InventoryItem) throws
    func update(_ item: InventoryItem) throws
    func delete(_ id: UUID) throws
    func fetchAll() throws -> [InventoryItem]
    func fetchByType(_ type: CollectionType) throws -> [InventoryItem]
    func fetchByLocation(_ locationId: UUID) throws -> [InventoryItem]
    func fetchByCustomField(key: String, value: String) throws -> [InventoryItem]
    
    // Add new trash-related methods to protocol
    func fetchDeletedItems() throws -> [InventoryItem]
    func restoreItem(_ id: UUID) throws
    func emptyTrash() throws
    func getTrashCount() throws -> Int
    func saveBatch(_ items: [InventoryItem]) throws
    
    // Add new methods
    func getClassificationRules() -> [MediaTypeRule]
    func classifyItem(title: String, publisher: String?, description: String?) -> CollectionType
}

class SQLiteItemRepository: ItemRepository {
    private let db: DatabaseManager
    
    init(database: DatabaseManager = .shared) {
        self.db = database
    }
    
    func save(_ item: InventoryItem) throws {
        print("Saving item \(item.id) with location \(String(describing: item.locationId))")
        
        // First check if item already exists
        let checkSql = "SELECT COUNT(*) FROM items WHERE id = ?;"
        var checkStatement: OpaquePointer?
        var exists = false
        
        if sqlite3_prepare_v2(db.connection, checkSql, -1, &checkStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(checkStatement, 1, (item.id.uuidString as NSString).utf8String, -1, nil)
            
            if sqlite3_step(checkStatement) == SQLITE_ROW {
                exists = sqlite3_column_int64(checkStatement, 0) > 0
            }
            
            sqlite3_finalize(checkStatement)
        }
        
        // If item exists, update it instead
        if exists {
            print("Item already exists, updating instead")
            try update(item)
            return
        }
        
        let sql = """
            INSERT INTO items (
                id, title, type, series, volume, condition, location_id,
                notes, date_added, barcode, thumbnail_url, author,
                manufacturer, original_publish_date, publisher, isbn,
                price, purchase_date, synopsis, created_at, updated_at,
                custom_image_data, image_source
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        try db.beginTransaction()
        
        do {
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db.connection, sql, -1, &statement, nil) == SQLITE_OK else {
                let error = String(cString: sqlite3_errmsg(db.connection))
                print("Failed to prepare item save: \(error)")
                throw DatabaseManager.DatabaseError.prepareFailed(error)
            }
            
            defer {
                sqlite3_finalize(statement)
            }
            
            let timestamp = Int(Date().timeIntervalSince1970)
            
            // Bind parameters with explicit location handling
            let parameters: [(Any?, Int32)] = [
                (item.id.uuidString, 1),
                (item.title, 2),
                (item.type.rawValue, 3),
                (item.series, 4),
                (item.volume, 5),
                (item.condition.rawValue, 6),
                (item.locationId?.uuidString, 7),
                (item.notes, 8),
                (Int(item.dateAdded.timeIntervalSince1970), 9),
                (item.barcode, 10),
                (item.thumbnailURL?.absoluteString, 11),
                (item.author, 12),
                (item.manufacturer, 13),
                (item.originalPublishDate.map { Int($0.timeIntervalSince1970) }, 14),
                (item.publisher, 15),
                (item.isbn, 16),
                (item.price?.databaseValue, 17),
                (item.purchaseDate.map { Int($0.timeIntervalSince1970) }, 18),
                (item.synopsis, 19),
                (timestamp, 20),
                (timestamp, 21),
                (item.customImageData, 22),
                (item.imageSource.rawValue, 23)
            ]
            
            // Bind each parameter
            for (value, index) in parameters {
                switch value {
                case let text as String:
                    sqlite3_bind_text(statement, index, (text as NSString).utf8String, -1, nil)
                case let int as Int:
                    sqlite3_bind_int64(statement, index, Int64(int))
                case let double as Double:
                    sqlite3_bind_double(statement, index, double)
                case let data as Data:
                    _ = data.withUnsafeBytes { bytes in
                        sqlite3_bind_blob(statement, index, bytes.baseAddress, Int32(data.count), nil)
                    }
                case .none:
                    sqlite3_bind_null(statement, index)
                default:
                    if let stringValue = value as? CustomStringConvertible {
                        sqlite3_bind_text(statement, index, (stringValue.description as NSString).utf8String, -1, nil)
                    } else {
                        sqlite3_bind_null(statement, index)
                    }
                }
            }
            
            if sqlite3_step(statement) != SQLITE_DONE {
                let error = String(cString: sqlite3_errmsg(db.connection))
                print("Failed to save item: \(error)")
                try db.rollbackTransaction()
                throw DatabaseManager.DatabaseError.insertFailed
            }
            
            try db.commitTransaction()
            print("Successfully saved item with location")
            
        } catch {
            try? db.rollbackTransaction()
            print("Error saving item: \(error.localizedDescription)")
            throw error
        }
    }
    
    func update(_ item: InventoryItem) throws {
        let sql = """
            UPDATE items SET
                title = ?, 
                type = ?, 
                series = ?, 
                volume = ?,
                condition = ?,
                location_id = ?,
                notes = ?,
                barcode = ?,
                thumbnail_url = ?,
                author = ?,
                manufacturer = ?,
                original_publish_date = ?,
                publisher = ?,
                isbn = ?,
                price = ?,
                purchase_date = ?,
                synopsis = ?,
                updated_at = ?,
                custom_image_data = ?,
                image_source = ?
            WHERE id = ?;
        """
        
        let timestamp = Int(Date().timeIntervalSince1970)
        print("Updating item \(item.id) with location \(String(describing: item.locationId))")
        
        let parameters: [(Any?, Int32)] = [
            (item.title, 1),
            (item.type.rawValue, 2),
            (item.series, 3),
            (item.volume, 4),
            (item.condition.rawValue, 5),
            (item.locationId?.uuidString, 6),
            (item.notes, 7),
            (item.barcode, 8),
            (item.thumbnailURL?.absoluteString, 9),
            (item.author, 10),
            (item.manufacturer, 11),
            (item.originalPublishDate.map { Int($0.timeIntervalSince1970) }, 12),
            (item.publisher, 13),
            (item.isbn, 14),
            (item.price?.databaseValue, 15),
            (item.purchaseDate.map { Int($0.timeIntervalSince1970) }, 16),
            (item.synopsis, 17),
            (timestamp, 18),
            (item.customImageData, 19),
            (item.imageSource.rawValue, 20),
            (item.id.uuidString, 21)
        ]
        
        // Add debug prints
        print("Updating with image data: \(item.customImageData != nil)")
        print("SQL Error: \(String(cString: sqlite3_errmsg(db.connection)))")
        
        try db.beginTransaction()
        
        do {
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db.connection, sql, -1, &statement, nil) == SQLITE_OK else {
                let error = String(cString: sqlite3_errmsg(db.connection))
                print("Failed to prepare item update: \(error)")
                throw DatabaseManager.DatabaseError.prepareFailed(error)
            }
            
            defer {
                sqlite3_finalize(statement)
            }
            
            // Bind all parameters
            for (value, index) in parameters {
                switch value {
                case let text as String:
                    sqlite3_bind_text(statement, index, (text as NSString).utf8String, -1, nil)
                case let int as Int:
                    sqlite3_bind_int64(statement, index, Int64(int))
                case let double as Double:
                    sqlite3_bind_double(statement, index, double)
                case let data as Data:
                    _ = data.withUnsafeBytes { bytes in
                        sqlite3_bind_blob(statement, index, bytes.baseAddress, Int32(data.count), nil)
                    }
                case .none:
                    sqlite3_bind_null(statement, index)
                default:
                    if let stringValue = value as? CustomStringConvertible {
                        sqlite3_bind_text(statement, index, (stringValue.description as NSString).utf8String, -1, nil)
                    } else {
                        sqlite3_bind_null(statement, index)
                    }
                }
            }
            
            if sqlite3_step(statement) != SQLITE_DONE {
                let error = String(cString: sqlite3_errmsg(db.connection))
                print("Failed to execute item update: \(error)")
                try db.rollbackTransaction()
                throw DatabaseManager.DatabaseError.updateFailed
            }
            
            let rowsAffected = sqlite3_changes(db.connection)
            print("Rows affected by item update: \(rowsAffected)")
            
            try db.commitTransaction()
            print("Successfully updated item with location")
            
        } catch {
            try? db.rollbackTransaction()
            print("Error updating item: \(error.localizedDescription)")
            throw error
        }
    }
    
    func delete(_ id: UUID) throws {
        let sql = """
            UPDATE items 
            SET deleted_at = ?,
                updated_at = ?
            WHERE id = ? AND deleted_at IS NULL
        """
        
        let timestamp = Int(Date().timeIntervalSince1970)
        let parameters: [Any] = [timestamp, timestamp, id.uuidString]
        
        db.executeStatement(sql, parameters: parameters)
    }
    
    func fetchAll() throws -> [InventoryItem] {
        print("SQLiteItemRepository: Fetching all items from database")
        let sql = """
            \(baseSelectSQL())
            ORDER BY title;
        """
        do {
            let items = try fetchItems(sql)
            print("SQLiteItemRepository: Successfully fetched \(items.count) items")
            
            // Debug the first few items
            if !items.isEmpty {
                let sample = min(3, items.count)
                for i in 0..<sample {
                    let item = items[i]
                    print("Sample item \(i+1): \(item.title) (ID: \(item.id), Type: \(item.type.rawValue))")
                }
            }
            
            return items
        } catch let error as DatabaseManager.DatabaseError {
            print("SQLiteItemRepository: Database error fetching items: \(error.localizedDescription)")
            throw error
        } catch {
            print("SQLiteItemRepository: Unexpected error fetching items: \(error.localizedDescription)")
            throw DatabaseManager.DatabaseError.invalidData
        }
    }
    
    func fetchByType(_ type: CollectionType) throws -> [InventoryItem] {
        let sql = """
            \(baseSelectSQL())
            AND type = ?
            ORDER BY title;
        """
        return try fetchItems(sql, parameters: [type.rawValue])
    }
    
    func fetchByLocation(_ locationId: UUID) throws -> [InventoryItem] {
        let sql = """
            \(baseSelectSQL())
            AND location_id = ?
            ORDER BY title;
        """
        return try fetchItems(sql, parameters: [locationId.uuidString])
    }
    
    func fetchByCustomField(key: String, value: String) throws -> [InventoryItem] {
        let sql = """
            SELECT i.* FROM items i
            INNER JOIN custom_fields cf ON cf.item_id = i.id
            WHERE cf.key = ? AND cf.value = ? AND i.deleted_at IS NULL
            ORDER BY i.title;
        """
        return try fetchItems(sql, parameters: [key, value])
    }
    
    private func fetchItems(_ sql: String, parameters: [Any]? = nil) throws -> [InventoryItem] {
        var items: [InventoryItem] = []
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db.connection, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseManager.DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db.connection)))
        }
        defer {
            sqlite3_finalize(statement)
        }
        
        if let params = parameters {
            for (index, param) in params.enumerated() {
                let idx = Int32(index + 1)
                if let text = param as? String {
                    sqlite3_bind_text(statement, idx, text.cString(using: .utf8), -1, nil)
                } else if let number = param as? Int {
                    sqlite3_bind_int64(statement, idx, Int64(number))
                } else if let number = param as? Double {
                    sqlite3_bind_double(statement, idx, number)
                }
                // Add other parameter types as needed
            }
        }
        
        while sqlite3_step(statement) == SQLITE_ROW {
            if let item = try parseItem(from: statement) {
                items.append(item)
            }
        }
        
        return items
    }
    
    private func parseItem(from statement: OpaquePointer?) throws -> InventoryItem? {
        guard let statement = statement else { return nil }
        
        // Extract values from columns
        guard
            let idString = sqlite3_column_text(statement, 0).map({ String(cString: $0) }),
            let id = UUID(uuidString: idString),
            let title = sqlite3_column_text(statement, 1).map({ String(cString: $0) }),
            let typeString = sqlite3_column_text(statement, 2).map({ String(cString: $0) }),
            let type = CollectionType(rawValue: typeString),
            let conditionString = sqlite3_column_text(statement, 5).map({ String(cString: $0) }),
            let condition = ItemCondition(rawValue: conditionString)
        else {
            throw DatabaseManager.DatabaseError.invalidData
        }
        
        // Optional values
        let series = sqlite3_column_text(statement, 3).map { String(cString: $0) }
        let volume = sqlite3_column_int(statement, 4)
        let locationId = sqlite3_column_text(statement, 6).map { String(cString: $0) }.flatMap { UUID(uuidString: $0) }
        let notes = sqlite3_column_text(statement, 7).map { String(cString: $0) }
        let dateAdded = Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 8)))
        let barcode = sqlite3_column_text(statement, 9).map { String(cString: $0) }
        let thumbnailURL = sqlite3_column_text(statement, 10)
            .map { String(cString: $0) }
            .flatMap { URL(string: $0) }
        let author = sqlite3_column_text(statement, 11).map { String(cString: $0) }
        let manufacturer = sqlite3_column_text(statement, 12).map { String(cString: $0) }
        let originalPublishDate = sqlite3_column_int64(statement, 13) > 0 
            ? Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 13)))
            : nil
        let publisher = sqlite3_column_text(statement, 14).map { String(cString: $0) }
        let isbn = sqlite3_column_text(statement, 15).map { String(cString: $0) }
        let price = sqlite3_column_double(statement, 16) > 0 
            ? Price.fromDatabase(sqlite3_column_double(statement, 16))
            : nil
        let purchaseDate = sqlite3_column_int64(statement, 17) > 0
            ? Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 17)))
            : nil
        let synopsis = sqlite3_column_text(statement, 18).map { String(cString: $0) }
        
        let imageData: Data? = {
            if let blob = sqlite3_column_blob(statement, 22) {
                let length = sqlite3_column_bytes(statement, 22)
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(length))
                buffer.initialize(from: blob.assumingMemoryBound(to: UInt8.self), count: Int(length))
                return Data(bytesNoCopy: buffer, count: Int(length), deallocator: .free)
            }
            return nil
        }()
        
        let imageSource = {
            if let sourceText = sqlite3_column_text(statement, 23) {
                return ImageSource(rawValue: String(cString: sourceText)) ?? .none
            }
            return ImageSource.none
        }()
        
        return InventoryItem(
            title: title,
            type: type,
            series: series,
            volume: volume > 0 ? Int(volume) : nil,
            condition: condition,
            locationId: locationId,
            notes: notes,
            id: id,
            dateAdded: dateAdded,
            barcode: barcode,
            thumbnailURL: thumbnailURL,
            author: author,
            manufacturer: manufacturer,
            originalPublishDate: originalPublishDate,
            publisher: publisher,
            isbn: isbn,
            price: price,
            purchaseDate: purchaseDate,
            synopsis: synopsis,
            customImageData: imageData,
            imageSource: imageSource
        )
    }
    
    // Add a new method to handle fetching non-deleted items
    private func baseSelectSQL() -> String {
        """
        SELECT * FROM items 
        WHERE deleted_at IS NULL
        """
    }
    
    // Add new method to restore deleted items
    func restoreItem(_ id: UUID) throws {
        let sql = """
            UPDATE items
            SET deleted_at = NULL,
                updated_at = ?
            WHERE id = ?;
        """
        let timestamp = Int(Date().timeIntervalSince1970)
        let parameters: [Any] = [timestamp, id.uuidString]
        
        db.executeStatement(sql, parameters: parameters)
    }
    
    // Add method to fetch deleted items
    func fetchDeletedItems() throws -> [InventoryItem] {
        let sql = """
            SELECT * FROM items
            WHERE deleted_at IS NOT NULL
            ORDER BY deleted_at DESC;
        """
        return try fetchItems(sql)
    }
    
    // Add method for permanent deletion
    func permanentlyDelete(_ id: UUID) throws {
        do {
            try db.beginTransaction()
            
            // First delete any custom fields
            let deleteCustomFieldsSQL = "DELETE FROM custom_fields WHERE item_id = ?;"
            db.executeStatement(deleteCustomFieldsSQL, parameters: [id.uuidString])
            
            // Then delete the item
            let deleteItemSQL = "DELETE FROM items WHERE id = ?;"
            db.executeStatement(deleteItemSQL, parameters: [id.uuidString])
            
            try db.commitTransaction()
        } catch {
            try? db.rollbackTransaction()
            throw error
        }
    }
    
    // Add method to permanently delete all items in trash
    func emptyTrash() throws {
        do {
            try db.beginTransaction()
            
            // First delete custom fields for deleted items
            let deleteCustomFieldsSQL = """
                DELETE FROM custom_fields 
                WHERE item_id IN (
                    SELECT id FROM items 
                    WHERE deleted_at IS NOT NULL
                );
            """
            db.executeStatement(deleteCustomFieldsSQL)
            
            // Then delete the items
            let deleteItemsSQL = "DELETE FROM items WHERE deleted_at IS NOT NULL;"
            db.executeStatement(deleteItemsSQL)
            
            try db.commitTransaction()
        } catch {
            try? db.rollbackTransaction()
            throw error
        }
    }
    
    // Add method to get trash count
    func getTrashCount() throws -> Int {
        let sql = "SELECT COUNT(*) FROM items WHERE deleted_at IS NOT NULL;"
        var statement: OpaquePointer?
        var count = 0
        
        guard sqlite3_prepare_v2(db.connection, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseManager.DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db.connection)))
        }
        defer {
            sqlite3_finalize(statement)
        }
        
        if sqlite3_step(statement) == SQLITE_ROW {
            count = Int(sqlite3_column_int64(statement, 0))
        }
        
        return count
    }
    
    func fetchTrashed() throws -> [InventoryItem] {
        let sql = """
            SELECT * FROM items 
            WHERE deleted_at IS NOT NULL
            ORDER BY deleted_at DESC
        """
        return try fetchItems(sql)
    }
    
    // Add a method to verify item-location relationship
    func verifyItemLocation(_ itemId: UUID) {
        let sql = """
            SELECT i.id, i.title, i.location_id, l.id, l.name 
            FROM items i 
            LEFT JOIN locations l ON i.location_id = l.id 
            WHERE i.id = ? AND i.deleted_at IS NULL;
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db.connection, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (itemId.uuidString as NSString).utf8String, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                let itemTitle = sqlite3_column_text(statement, 1).map { String(cString: $0) } ?? "unknown"
                let locationId = sqlite3_column_text(statement, 2).map { String(cString: $0) }
                let locationName = sqlite3_column_text(statement, 4).map { String(cString: $0) }
                
                print("Item Location Verification:")
                print("Item: \(itemTitle)")
                print("Location ID: \(locationId ?? "nil")")
                print("Location Name: \(locationName ?? "nil")")
            }
            
            sqlite3_finalize(statement)
        }
    }
    
    func saveBatch(_ items: [InventoryItem]) throws {
        try db.beginTransaction()
        do {
            for item in items {
                try save(item)
            }
            try db.commitTransaction()
        } catch {
            try? db.rollbackTransaction()
            throw error
        }
    }
    
    // Add new methods
    func getClassificationRules() -> [MediaTypeRule] {
        let sql = """
            SELECT id, pattern, pattern_type, priority, media_type
            FROM classification_rules
            ORDER BY priority, pattern;
        """
        
        var rules: [MediaTypeRule] = []
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db.connection, sql, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int64(statement, 0))
                let pattern = String(cString: sqlite3_column_text(statement, 1))
                let patternType = MediaTypeRule.PatternType(rawValue: String(cString: sqlite3_column_text(statement, 2)))!
                let priority = Int(sqlite3_column_int64(statement, 3))
                let mediaType = CollectionType(rawValue: String(cString: sqlite3_column_text(statement, 4)))!
                
                let rule = MediaTypeRule(
                    id: id,
                    pattern: pattern,
                    patternType: patternType,
                    priority: priority,
                    mediaType: mediaType
                )
                rules.append(rule)
            }
        }
        sqlite3_finalize(statement)
        return rules
    }
    
    func classifyItem(title: String, publisher: String?, description: String?) -> CollectionType {
        let rules = getClassificationRules()
        
        // Check publisher rules first
        if let publisher = publisher?.lowercased() {
            if let match = rules.first(where: { rule in
                rule.patternType == .publisher && publisher.contains(rule.pattern.lowercased())
            }) {
                return match.mediaType
            }
        }
        
        // Then check title
        let lowercaseTitle = title.lowercased()
        if let match = rules.first(where: { rule in
            rule.patternType == .title && lowercaseTitle.contains(rule.pattern.lowercased())
        }) {
            return match.mediaType
        }
        
        // Finally check description
        if let description = description?.lowercased() {
            if let match = rules.first(where: { rule in
                rule.patternType == .description && description.contains(rule.pattern.lowercased())
            }) {
                return match.mediaType
            }
        }
        
        return .books // Default type
    }
} 