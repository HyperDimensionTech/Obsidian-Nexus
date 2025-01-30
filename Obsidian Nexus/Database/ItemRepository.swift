import Foundation
import SQLite3

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
}

class SQLiteItemRepository: ItemRepository {
    private let db: DatabaseManager
    
    init(database: DatabaseManager = .shared) {
        self.db = database
    }
    
    func save(_ item: InventoryItem) throws {
        print("Attempting to save item: \(item.title)") // Debug
        
        let sql = """
            INSERT INTO items (
                id, title, type, series, volume, condition, location_id,
                notes, date_added, barcode, thumbnail_url, author,
                manufacturer, original_publish_date, publisher, isbn,
                price, purchase_date, synopsis, created_at, updated_at,
                deleted_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL);
        """
        
        let timestamp = Int(Date().timeIntervalSince1970)
        let parameters: [Any] = [
            item.id.uuidString,  // Make sure ID is first parameter
            item.title,
            item.type.rawValue,
            item.series as Any,
            item.volume as Any,
            item.condition.rawValue,
            item.locationId?.uuidString as Any,
            item.notes as Any,
            Int(item.dateAdded.timeIntervalSince1970),
            item.barcode as Any,
            item.thumbnailURL?.absoluteString as Any,
            item.author as Any,
            item.manufacturer as Any,
            item.originalPublishDate.map { Int($0.timeIntervalSince1970) } as Any,
            item.publisher as Any,
            item.isbn as Any,
            (item.price as NSDecimalNumber?)?.doubleValue as Any,
            item.purchaseDate.map { Int($0.timeIntervalSince1970) } as Any,
            item.synopsis as Any,
            timestamp,
            timestamp
        ]
        
        print("Parameters: \(parameters)") // Debug
        
        // Debug parameter binding
        for (index, param) in parameters.enumerated() {
            print("Binding parameter \(index + 1): \(param)")
        }
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db.connection, sql, -1, &statement, nil) == SQLITE_OK else {
            let error = String(cString: sqlite3_errmsg(db.connection))
            print("Prepare failed: \(error)") // Debug
            throw DatabaseManager.DatabaseError.prepareFailed(error)
        }
        
        // Bind parameters
        for (index, parameter) in parameters.enumerated() {
            let parameterIndex = Int32(index + 1)
            switch parameter {
            case let value as String:
                sqlite3_bind_text(statement, parameterIndex, (value as NSString).utf8String, -1, nil)
            case let value as Int:
                sqlite3_bind_int64(statement, parameterIndex, Int64(value))
            case let value as Double:
                sqlite3_bind_double(statement, parameterIndex, value)
            case is NSNull:
                sqlite3_bind_null(statement, parameterIndex)
            default:
                if let value = parameter as? CustomStringConvertible {
                    sqlite3_bind_text(statement, parameterIndex, (value.description as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(statement, parameterIndex)
                }
            }
        }
        
        // Execute
        if sqlite3_step(statement) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(db.connection))
            print("Insert failed: \(error)") // Debug
            throw DatabaseManager.DatabaseError.insertFailed
        }
        
        sqlite3_finalize(statement)
    }
    
    func update(_ item: InventoryItem) throws {
        let sql = """
            UPDATE items SET
                title = ?, type = ?, series = ?, volume = ?,
                condition = ?, location_id = ?, notes = ?,
                barcode = ?, thumbnail_url = ?, author = ?,
                manufacturer = ?, original_publish_date = ?,
                publisher = ?, isbn = ?, price = ?,
                purchase_date = ?, synopsis = ?,
                updated_at = ?
            WHERE id = ?;
        """
        
        let parameters: [Any] = [
            item.title,
            item.type.rawValue,
            item.series as Any,
            item.volume as Any,
            item.condition.rawValue,
            item.locationId?.uuidString as Any,
            item.notes as Any,
            item.barcode as Any,
            item.thumbnailURL?.absoluteString as Any,
            item.author as Any,
            item.manufacturer as Any,
            item.originalPublishDate.map { Int($0.timeIntervalSince1970) } as Any,
            item.publisher as Any,
            item.isbn as Any,
            (item.price as NSDecimalNumber?)?.doubleValue as Any,
            item.purchaseDate.map { Int($0.timeIntervalSince1970) } as Any,
            item.synopsis as Any,
            Int(Date().timeIntervalSince1970),
            item.id.uuidString
        ]
        
        db.executeStatement(sql, parameters: parameters)
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
        let sql = """
            \(baseSelectSQL())
            ORDER BY title;
        """
        return try fetchItems(sql)
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
            ? Decimal(sqlite3_column_double(statement, 16))
            : nil
        let purchaseDate = sqlite3_column_int64(statement, 17) > 0
            ? Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 17)))
            : nil
        let synopsis = sqlite3_column_text(statement, 18).map { String(cString: $0) }
        
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
            synopsis: synopsis
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
} 