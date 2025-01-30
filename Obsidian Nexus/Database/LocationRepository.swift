import Foundation
import SQLite3

protocol LocationRepository {
    func save(_ location: StorageLocation) throws
    func update(_ location: StorageLocation) throws
    func delete(_ locationId: UUID) throws
    func fetchAll() throws -> [StorageLocation]
    func fetchChildren(of parentId: UUID) throws -> [StorageLocation]
    func fetchById(_ id: UUID) throws -> StorageLocation?
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
            location.parentId?.uuidString as Any,
            timestamp,
            timestamp
        ]
        
        db.executeStatement(sql, parameters: parameters)
    }
    
    func update(_ location: StorageLocation) throws {
        let sql = """
            UPDATE locations 
            SET name = ?, type = ?, parent_id = ?, updated_at = ?
            WHERE id = ? AND deleted_at IS NULL;
        """
        
        let timestamp = Int(Date().timeIntervalSince1970)
        let parameters: [Any] = [
            location.name,
            location.type.rawValue,
            location.parentId?.uuidString as Any,
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
            SELECT * FROM locations 
            WHERE deleted_at IS NULL 
            ORDER BY name;
        """
        return try fetchLocations(sql)
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
        let locations = try fetchLocations(sql, parameters: [id.uuidString])
        return locations.first
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
} 