import Foundation
import SQLite3

protocol ISBNMappingRepository {
    func save(_ mapping: ISBNMapping) throws
    func fetchAll() throws -> [ISBNMapping]
    func fetchByISBN(_ isbn: String) throws -> ISBNMapping?
    func delete(_ isbn: String) throws
    func deleteAll() throws
    func executeDirectDelete(isbn: String) throws
}

class SQLiteISBNMappingRepository: ISBNMappingRepository {
    private let db: DatabaseManager
    
    init(database: DatabaseManager = .shared) {
        self.db = database
    }
    
    func save(_ mapping: ISBNMapping) throws {
        let sql = """
            INSERT OR REPLACE INTO isbn_mappings (
                incorrect_isbn, google_books_id, title, is_reprint, date_added
            ) VALUES (?, ?, ?, ?, ?);
        """
        
        let dateTimestamp = Int(mapping.dateAdded.timeIntervalSince1970)
        let isReprint = mapping.isReprint ? 1 : 0
        
        let parameters: [Any] = [
            mapping.incorrectISBN,
            mapping.correctGoogleBooksID,
            mapping.title,
            isReprint,
            dateTimestamp
        ]
        
        try db.executeStatement(sql, parameters: parameters)
    }
    
    func fetchAll() throws -> [ISBNMapping] {
        let sql = """
            SELECT incorrect_isbn, google_books_id, title, is_reprint, date_added
            FROM isbn_mappings
            ORDER BY date_added DESC;
        """
        
        var mappings: [ISBNMapping] = []
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db.connection, sql, -1, &statement, nil) == SQLITE_OK else {
            let error = String(cString: sqlite3_errmsg(db.connection))
            throw DatabaseManager.DatabaseError.prepareFailed(error)
        }
        
        defer {
            sqlite3_finalize(statement)
        }
        
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let mapping = parseMapping(from: statement) else { continue }
            mappings.append(mapping)
        }
        
        return mappings
    }
    
    func fetchByISBN(_ isbn: String) throws -> ISBNMapping? {
        let sql = """
            SELECT incorrect_isbn, google_books_id, title, is_reprint, date_added
            FROM isbn_mappings
            WHERE incorrect_isbn = ?;
        """
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db.connection, sql, -1, &statement, nil) == SQLITE_OK else {
            let error = String(cString: sqlite3_errmsg(db.connection))
            throw DatabaseManager.DatabaseError.prepareFailed(error)
        }
        
        defer {
            sqlite3_finalize(statement)
        }
        
        sqlite3_bind_text(statement, 1, (isbn as NSString).utf8String, -1, nil)
        
        if sqlite3_step(statement) == SQLITE_ROW {
            return parseMapping(from: statement)
        }
        
        return nil
    }
    
    func delete(_ isbn: String) throws {
        let sql = "DELETE FROM isbn_mappings WHERE incorrect_isbn = ?;"
        try db.executeStatement(sql, parameters: [isbn])
    }
    
    func deleteAll() throws {
        let sql = "DELETE FROM isbn_mappings;"
        try db.executeStatement(sql)
    }
    
    // MARK: - Public Methods
    
    /// Execute a direct SQL delete statement for emergency fixes
    func executeDirectDelete(isbn: String) throws {
        let sql = "DELETE FROM isbn_mappings WHERE incorrect_isbn = ?;"
        try db.executeStatement(sql, parameters: [isbn])
        print("Executed direct SQL delete for ISBN: \(isbn)")
    }
    
    // MARK: - Private Methods
    
    private func parseMapping(from statement: OpaquePointer?) -> ISBNMapping? {
        guard let statement = statement else { return nil }
        
        // First check if we have valid column data before trying to access it
        guard sqlite3_column_type(statement, 0) != SQLITE_NULL,
              sqlite3_column_type(statement, 1) != SQLITE_NULL,
              sqlite3_column_type(statement, 2) != SQLITE_NULL else {
            print("Null column data found when parsing ISBN mapping")
            return nil
        }
        
        // Now safely extract the text values
        guard let isbnCString = sqlite3_column_text(statement, 0),
              let googleBookIdCString = sqlite3_column_text(statement, 1),
              let titleCString = sqlite3_column_text(statement, 2) else {
            print("Failed to extract column text data from ISBN mapping")
            return nil
        }
        
        let incorrectISBN = String(cString: isbnCString)
        let googleBooksId = String(cString: googleBookIdCString)
        let title = String(cString: titleCString)
        let isReprint = sqlite3_column_int(statement, 3) != 0
        let dateTimestamp = sqlite3_column_int64(statement, 4)
        let dateAdded = Date(timeIntervalSince1970: TimeInterval(dateTimestamp))
        
        return ISBNMapping(
            incorrectISBN: incorrectISBN,
            correctGoogleBooksID: googleBooksId,
            title: title,
            isReprint: isReprint,
            dateAdded: dateAdded
        )
    }
} 