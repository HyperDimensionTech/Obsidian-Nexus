import Foundation
import SQLite3

protocol LocationRepository {
    func save(_ location: StorageLocation) throws
    func update(_ location: StorageLocation) throws
    func delete(_ locationId: UUID) throws
    func fetchAll() throws -> [StorageLocation]
    func fetchChildren(of parentId: UUID) throws -> [StorageLocation]
    func fetchById(_ id: UUID) throws -> StorageLocation?
    func fetchByName(_ name: String) throws -> StorageLocation?
    func updateParent(_ locationId: UUID, newParentId: UUID?) throws
    func updateName(_ locationId: UUID, newName: String) throws
    func verifyDatabaseState()
}

class SQLiteLocationRepository: LocationRepository {
    private let db: DatabaseManager
    
    init(database: DatabaseManager = .shared) {
        self.db = database
    }
    
    func save(_ location: StorageLocation) throws {
        let sql = """
            INSERT INTO locations (
                id, name, type, parent_id, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?);
        """
        
        let timestamp = Int(Date().timeIntervalSince1970)
        let parameters: [Any] = [
            location.id.uuidString,
            location.name,
            location.type.rawValue,
            location.parentId?.uuidString ?? NSNull(),
            timestamp,
            timestamp
        ]
        
        db.executeStatement(sql, parameters: parameters)
    }
    
    func update(_ location: StorageLocation) throws {
        let sql = """
            UPDATE locations 
            SET name = ?, 
                type = ?, 
                parent_id = ?, 
                updated_at = ?
            WHERE id = ? AND deleted_at IS NULL;
        """
        
        let timestamp = Int(Date().timeIntervalSince1970)
        let parameters: [Any] = [
            location.name,
            location.type.rawValue,
            location.parentId?.uuidString ?? NSNull(),
            timestamp,
            location.id.uuidString
        ]
        
        db.executeStatement(sql, parameters: parameters)
    }
    
    func delete(_ locationId: UUID) throws {
        let sql = """
            UPDATE locations 
            SET deleted_at = ? 
            WHERE id = ? OR parent_id = ?;
        """
        
        let timestamp = Int(Date().timeIntervalSince1970)
        db.executeStatement(sql, parameters: [
            timestamp,
            locationId.uuidString,
            locationId.uuidString
        ])
    }
    
    func fetchAll() throws -> [StorageLocation] {
        let sql = """
            SELECT DISTINCT id, name, type, parent_id
            FROM locations 
            WHERE deleted_at IS NULL 
                AND id IS NOT NULL 
                AND name IS NOT NULL 
                AND type IS NOT NULL
                AND LENGTH(TRIM(id)) > 0
                AND LENGTH(TRIM(name)) > 0
                AND LENGTH(TRIM(type)) > 0
            ORDER BY name;
        """
        
        var locations: [StorageLocation] = []
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db.connection, sql, -1, &statement, nil) == SQLITE_OK else {
            let error = String(cString: sqlite3_errmsg(db.connection))
            print("Error preparing statement: \(error)")
            throw DatabaseManager.DatabaseError.prepareFailed(error)
        }
        
        defer {
            sqlite3_finalize(statement)
        }
        
        while sqlite3_step(statement) == SQLITE_ROW {
            if let location = try? parseLocation(from: statement) {
                locations.append(location)
            }
        }
        
        return locations
    }
    
    func fetchChildren(of parentId: UUID) throws -> [StorageLocation] {
        let sql = """
            SELECT * FROM locations 
            WHERE parent_id = ? AND deleted_at IS NULL 
            ORDER BY name;
        """
        return try fetchLocations(sql, parameters: [parentId.uuidString])
    }
    
    func fetchById(_ id: UUID) throws -> StorageLocation? {
        let sql = """
            SELECT * FROM locations 
            WHERE id = ? AND deleted_at IS NULL;
        """
        
        let results = try fetchLocations(sql, parameters: [id.uuidString])
        return results.first
    }
    
    func fetchByName(_ name: String) throws -> StorageLocation? {
        let sql = """
            SELECT * FROM locations 
            WHERE name = ? AND deleted_at IS NULL;
        """
        
        let results = try fetchLocations(sql, parameters: [name])
        return results.first
    }
    
    func updateParent(_ locationId: UUID, newParentId: UUID?) throws {
        let sql = """
            UPDATE locations 
            SET parent_id = ?, 
                updated_at = ?
            WHERE id = ?;
        """
        
        let timestamp = Int(Date().timeIntervalSince1970)
        let parameters: [Any] = [
            newParentId?.uuidString ?? NSNull(),
            timestamp,
            locationId.uuidString
        ]
        
        db.executeStatement(sql, parameters: parameters)
    }
    
    func updateName(_ locationId: UUID, newName: String) throws {
        let sql = """
            UPDATE locations 
            SET name = ?, 
                updated_at = ?
            WHERE id = ? AND deleted_at IS NULL;
        """
        
        let timestamp = Int(Date().timeIntervalSince1970)
        print("Attempting to rename location \(locationId) to '\(newName)'")
        
        try db.beginTransaction()
        
        do {
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db.connection, sql, -1, &statement, nil) == SQLITE_OK else {
                let error = String(cString: sqlite3_errmsg(db.connection))
                print("Failed to prepare rename statement: \(error)")
                throw DatabaseManager.DatabaseError.prepareFailed(error)
            }
            
            defer {
                sqlite3_finalize(statement)
            }
            
            // Bind parameters with error checking
            let bindResults = [
                sqlite3_bind_text(statement, 1, (newName as NSString).utf8String, -1, nil),
                sqlite3_bind_int64(statement, 2, Int64(timestamp)),
                sqlite3_bind_text(statement, 3, (locationId.uuidString as NSString).utf8String, -1, nil)
            ]
            
            for (index, result) in bindResults.enumerated() {
                if result != SQLITE_OK {
                    let error = String(cString: sqlite3_errmsg(db.connection))
                    print("Failed to bind parameter \(index + 1): \(error)")
                    try db.rollbackTransaction()
                    throw DatabaseManager.DatabaseError.prepareFailed(error)
                }
            }
            
            let stepResult = sqlite3_step(statement)
            if stepResult != SQLITE_DONE {
                let error = String(cString: sqlite3_errmsg(db.connection))
                print("Failed to execute rename: \(error)")
                try db.rollbackTransaction()
                throw DatabaseManager.DatabaseError.updateFailed
            }
            
            // Check if any rows were affected
            let rowsAffected = sqlite3_changes(db.connection)
            print("Rows affected by rename: \(rowsAffected)")
            if rowsAffected == 0 {
                print("Warning: No rows were updated during rename")
            }
            
            try db.commitTransaction()
            print("Successfully renamed location")
            
        } catch {
            try? db.rollbackTransaction()
            print("Error during rename: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func fetchLocations(_ sql: String, parameters: [Any]? = nil) throws -> [StorageLocation] {
        var locations: [StorageLocation] = []
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db.connection, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseManager.DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db.connection)))
        }
        
        if let params = parameters {
            for (index, param) in params.enumerated() {
                let idx = Int32(index + 1)
                if let text = param as? String {
                    sqlite3_bind_text(statement, idx, text.cString(using: .utf8), -1, nil)
                }
            }
        }
        
        while sqlite3_step(statement) == SQLITE_ROW {
            if let location = try parseLocation(from: statement) {
                locations.append(location)
            }
        }
        
        sqlite3_finalize(statement)
        return locations
    }
    
    private func parseLocation(from statement: OpaquePointer?) throws -> StorageLocation? {
        guard let statement = statement else { return nil }
        
        do {
            // Get raw column data and print for debugging
            let idRaw = String(cString: sqlite3_column_text(statement, 0))
            let nameRaw = String(cString: sqlite3_column_text(statement, 1))
            let typeRaw = String(cString: sqlite3_column_text(statement, 2))
            let parentIdRaw = sqlite3_column_text(statement, 3).map { String(cString: $0) }
            
            print("Raw values from database:")
            print("ID: \(idRaw)")
            print("Name: \(nameRaw)")
            print("Type: \(typeRaw)")
            print("ParentID: \(String(describing: parentIdRaw))")
            
            // Convert ID
            guard let id = UUID(uuidString: idRaw) else {
                print("Failed to parse UUID: \(idRaw)")
                throw DatabaseManager.DatabaseError.invalidData
            }
            
            // Convert type
            guard let type = StorageLocation.LocationType(rawValue: typeRaw) else {
                print("Failed to parse location type: \(typeRaw)")
                throw DatabaseManager.DatabaseError.invalidData
            }
            
            // Handle optional parent ID
            let parentId: UUID?
            if let parentIdString = parentIdRaw {
                parentId = UUID(uuidString: parentIdString)
            } else {
                parentId = nil
            }
            
            // Create location
            return StorageLocation(
                id: id,
                name: nameRaw,
                type: type,
                parentId: parentId,
                childIds: []
            )
        } catch {
            print("Error parsing location: \(error.localizedDescription)")
            // Print column data types for debugging
            print("Column types:")
            print("ID type: \(sqlite3_column_type(statement, 0))")
            print("Name type: \(sqlite3_column_type(statement, 1))")
            print("Type type: \(sqlite3_column_type(statement, 2))")
            print("ParentID type: \(sqlite3_column_type(statement, 3))")
            throw DatabaseManager.DatabaseError.invalidData
        }
    }
    
    private func mapDatabaseRow(_ statement: OpaquePointer) throws -> StorageLocation {
        guard
            let idString = sqlite3_column_text(statement, 0).map({ String(cString: $0) }),
            let id = UUID(uuidString: idString),
            let name = sqlite3_column_text(statement, 1).map({ String(cString: $0) }),
            let typeString = sqlite3_column_text(statement, 2).map({ String(cString: $0) }),
            let type = StorageLocation.LocationType(rawValue: typeString)
        else {
            throw DatabaseManager.DatabaseError.invalidData
        }
        
        let parentId = sqlite3_column_text(statement, 3)
            .map { String(cString: $0) }
            .flatMap { UUID(uuidString: $0) }
        
        return StorageLocation(
            id: id,
            name: name,
            type: type,
            parentId: parentId
        )
    }
    
    func verifyDatabaseState() {
        let sql = "SELECT id, name, type, parent_id FROM locations WHERE deleted_at IS NULL;"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db.connection, sql, -1, &statement, nil) == SQLITE_OK else {
            let error = String(cString: sqlite3_errmsg(db.connection))
            print("Error preparing verification statement: \(error)")
            return
        }
        
        defer {
            sqlite3_finalize(statement)
        }
        
        print("\nCurrent Database State:")
        while sqlite3_step(statement) == SQLITE_ROW {
            // Get column values safely
            guard let idPtr = sqlite3_column_text(statement, 0),
                  let namePtr = sqlite3_column_text(statement, 1),
                  let typePtr = sqlite3_column_text(statement, 2) else {
                print("Error: Null values found in row")
                continue
            }
            
            let id = String(cString: idPtr)
            let name = String(cString: namePtr)
            let type = String(cString: typePtr)
            let parentId = sqlite3_column_text(statement, 3).map { String(cString: $0) }
            
            print("Location: id=\(id), name=\(name), type=\(type), parentId=\(String(describing: parentId))")
        }
        
        // Print any SQLite errors that occurred during iteration
        if sqlite3_errcode(db.connection) != SQLITE_OK && sqlite3_errcode(db.connection) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(db.connection))
            print("Error during database verification: \(error)")
        }
    }
} 