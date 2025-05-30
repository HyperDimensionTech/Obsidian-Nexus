import Foundation
import SQLite3
import UIKit

@MainActor
class DataManagementService: NSObject {
    static let shared = DataManagementService()
    private let storage: StorageManager
    private let fileManager: FileManager
    
    init(storage: StorageManager = .shared) {
        self.storage = storage
        self.fileManager = FileManager.default
        super.init()
    }
    
    // MARK: - Backup Operations
    
    func createBackup() async throws -> URL {
        // Get the database file URL
        let dbURL = try fileManager
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("obsidian_nexus.sqlite")
        
        // Create backup directory if it doesn't exist
        let backupDir = try fileManager
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Backups", isDirectory: true)
        
        try fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)
        
        // Create backup file with timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM dd, yyyy 'at' hh-mm-ss a"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX") // Ensures consistent formatting
        let timestamp = dateFormatter.string(from: Date())
        let backupURL = backupDir.appendingPathComponent("backup_\(timestamp).sqlite")
        
        // Copy database file to backup location
        try fileManager.copyItem(at: dbURL, to: backupURL)
        
        return backupURL
    }
    
    func saveBackupToCloud(_ backupURL: URL) async throws {
        // Create a temporary copy of the backup
        let tempDir = FileManager.default.temporaryDirectory
        let tempBackupURL = tempDir.appendingPathComponent(backupURL.lastPathComponent)
        try fileManager.copyItem(at: backupURL, to: tempBackupURL)
        
        // Present document picker for saving
        let documentPicker = UIDocumentPickerViewController(forExporting: [tempBackupURL])
        documentPicker.delegate = self
        documentPicker.modalPresentationStyle = .formSheet
        
        // Present the picker
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(documentPicker, animated: true)
        }
    }
    
    func restoreFromCloud() async throws {
        // Present document picker for importing
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.data])
        documentPicker.delegate = self
        documentPicker.modalPresentationStyle = .formSheet
        
        // Present the picker
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(documentPicker, animated: true)
        }
    }
    
    func restoreFromBackup(_ backupURL: URL) async throws {
        // Get the current database file URL
        let dbURL = try fileManager
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("obsidian_nexus.sqlite")
        
        // Close current database connection
        DatabaseManager.shared.closeConnection()
        
        // Remove current database file
        try? fileManager.removeItem(at: dbURL)
        
        // Copy backup file to database location
        try fileManager.copyItem(at: backupURL, to: dbURL)
        
        // Reopen database connection
        DatabaseManager.shared.reopenConnection()
        
        // Verify database integrity
        try await validateDatabase()
    }
    
    func listBackups() throws -> [URL] {
        let backupDir = try fileManager
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Backups", isDirectory: true)
        
        let backupFiles = try fileManager.contentsOfDirectory(
            at: backupDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        )
        
        return backupFiles.sorted { (url1, url2) in
            let date1 = try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
            let date2 = try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
            return (date1 ?? Date.distantPast) > (date2 ?? Date.distantPast)
        }
    }
    
    func deleteBackup(_ backupURL: URL) throws {
        try fileManager.removeItem(at: backupURL)
    }
    
    // MARK: - Validation
    
    private func validateDatabase() async throws {
        // Verify database structure
        let tables = ["items", "locations", "custom_fields"]
        for table in tables {
            let sql = "SELECT name FROM sqlite_master WHERE type='table' AND name=?;"
            var statement: OpaquePointer?
            
            guard sqlite3_prepare_v2(DatabaseManager.shared.connection, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseManager.DatabaseError.prepareFailed("Failed to prepare validation statement")
            }
            
            defer { sqlite3_finalize(statement) }
            
            sqlite3_bind_text(statement, 1, (table as NSString).utf8String, -1, nil)
            
            guard sqlite3_step(statement) == SQLITE_ROW else {
                throw DatabaseManager.DatabaseError.invalidData
            }
        }
        
        // Verify data integrity
        let integrityCheck = "PRAGMA integrity_check;"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(DatabaseManager.shared.connection, integrityCheck, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseManager.DatabaseError.prepareFailed("Failed to prepare integrity check")
        }
        
        defer { sqlite3_finalize(statement) }
        
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw DatabaseManager.DatabaseError.invalidData
        }
        
        let result = String(cString: sqlite3_column_text(statement, 0))
        guard result == "ok" else {
            throw DatabaseManager.DatabaseError.invalidData
        }
    }
    
    // MARK: - Import/Export Operations
    
    func exportData() async throws -> URL {
        let items = try storage.loadItems()
        let locations = try storage.loadLocations()
        let isbnMappings = try storage.getISBNMappingRepository().fetchAll()
        
        // Create CSV content for items
        var csvContent = "Title,Type,Series,Author,Publisher,ISBN,Price,Currency,PurchaseDate,Condition,Location,Synopsis\n"
        
        // Create ISO 8601 date formatter
        let dateFormatter = ISO8601DateFormatter()
        
        for item in items {
            let location = locations.first { $0.id == item.locationId }?.name ?? ""
            let priceString = item.price?.csvValue ?? ","
            let purchaseDate = item.purchaseDate.map { dateFormatter.string(from: $0) } ?? ""
            
            // Break up the complex expression into steps
            let title = item.title
            let type = item.type.rawValue
            let series = item.series ?? ""
            let author = item.author ?? ""
            let publisher = item.publisher ?? ""
            let isbn = item.isbn ?? ""
            let condition = item.condition.rawValue
            let synopsis = item.synopsis ?? ""
            
            // Create row components
            let rowComponents = [
                title,
                type,
                series,
                author,
                publisher,
                isbn,
                priceString,
                purchaseDate,
                condition,
                location,
                synopsis
            ]
            
            // Format each component
            let formattedComponents = rowComponents.map { component in
                "\"\(component.replacingOccurrences(of: "\"", with: "\"\""))\""
            }
            
            // Join components with commas
            let row = formattedComponents.joined(separator: ",")
            
            csvContent += row + "\n"
        }
        
        // Add ISBN mappings section if there are any mappings
        if !isbnMappings.isEmpty {
            // Add section delimiter
            csvContent += "\n#ISBN_MAPPINGS#\n"
            csvContent += "IncorrectISBN,GoogleBooksID,Title,IsReprint,DateAdded\n"
            
            for mapping in isbnMappings {
                let dateString = dateFormatter.string(from: mapping.dateAdded)
                let isReprintString = mapping.isReprint ? "true" : "false"
                
                let rowComponents = [
                    mapping.incorrectISBN,
                    mapping.correctGoogleBooksID,
                    mapping.title,
                    isReprintString,
                    dateString
                ]
                
                // Format each component
                let formattedComponents = rowComponents.map { component in
                    "\"\(component.replacingOccurrences(of: "\"", with: "\"\""))\""
                }
                
                // Join components with commas
                let row = formattedComponents.joined(separator: ",")
                csvContent += row + "\n"
            }
        }
        
        // Create export directory if it doesn't exist
        let exportDir = try getExportDirectory()
        
        // Create unique filename with timestamp
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let filename = "inventory_export_\(timestamp).csv"
        let fileURL = exportDir.appendingPathComponent(filename)
        
        // Write CSV content
        try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
        
        return fileURL
    }
    
    func importData(from fileURL: URL) async throws {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let contentSections = content.components(separatedBy: "\n#ISBN_MAPPINGS#\n")
        
        // Process items section (always the first section)
        let itemsContent = contentSections[0]
        let itemRows = itemsContent.components(separatedBy: .newlines)
        
        // Skip header row
        guard itemRows.count > 1 else { return }
        
        // Create ISO 8601 date formatter
        let dateFormatter = ISO8601DateFormatter()
        
        // Begin a transaction for better performance and data integrity
        try storage.beginTransaction()
        
        // Import inventory items
        for row in itemRows.dropFirst() {
            guard !row.isEmpty else { continue }
            
            let columns = parseCSVRow(row)
            guard columns.count >= 12 else { continue }
            
            // Parse price
            let price: Price?
            if let amount = Decimal(string: columns[6]), let currency = Price.Currency(rawValue: columns[7]) {
                price = Price(amount: amount, currency: currency)
            } else {
                price = nil
            }
            
            // Parse purchase date
            let purchaseDate = dateFormatter.date(from: columns[8])
            
            // Create item
            let item = InventoryItem(
                title: columns[0],
                type: CollectionType(rawValue: columns[1]) ?? .books,
                series: columns[2].isEmpty ? nil : columns[2],
                volume: Int(columns[3]),
                condition: ItemCondition(rawValue: columns[9]) ?? .good,
                notes: nil,
                author: columns[3].isEmpty ? nil : columns[3],
                originalPublishDate: nil,
                publisher: columns[4].isEmpty ? nil : columns[4],
                isbn: columns[5].isEmpty ? nil : columns[5],
                price: price,
                purchaseDate: purchaseDate,
                synopsis: columns[11].isEmpty ? nil : columns[11]
            )
            
            // Check for location
            if !columns[10].isEmpty {
                if let location = try storage.locationRepository.fetchByName(columns[10]) {
                    var updatedItem = item
                    updatedItem.locationId = location.id
                    try storage.save(updatedItem)
                } else {
                    let newLocation = StorageLocation(
                        name: columns[10],
                        type: .shelf,
                        parentId: nil
                    )
                    try storage.save(newLocation)
                    
                    var updatedItem = item
                    updatedItem.locationId = newLocation.id
                    try storage.save(updatedItem)
                }
            } else {
                try storage.save(item)
            }
        }
        
        // Process ISBN mappings section if it exists
        if contentSections.count > 1 {
            let mappingsContent = contentSections[1]
            let mappingRows = mappingsContent.components(separatedBy: .newlines)
            
            // Skip header row and process mappings
            let mappingRepository = storage.getISBNMappingRepository()
            
            for row in mappingRows.dropFirst() {
                guard !row.isEmpty else { continue }
                
                let columns = parseCSVRow(row)
                guard columns.count >= 5 else { continue }
                
                let incorrectISBN = columns[0]
                let googleBooksID = columns[1]
                let title = columns[2]
                let isReprint = columns[3].lowercased() == "true"
                let dateAdded = dateFormatter.date(from: columns[4]) ?? Date()
                
                let mapping = ISBNMapping(
                    incorrectISBN: incorrectISBN,
                    correctGoogleBooksID: googleBooksID,
                    title: title,
                    isReprint: isReprint,
                    dateAdded: dateAdded
                )
                
                try mappingRepository.save(mapping)
            }
        }
        
        // Commit the transaction
        try storage.commitTransaction()
        
        // Notify services of data import
        NotificationCenter.default.post(name: .dataImportCompleted, object: nil)
    }
    
    func getExportedFiles() async throws -> [URL] {
        let exportDir = try getExportDirectory()
        let files = try fileManager.contentsOfDirectory(
            at: exportDir,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey]
        )
        return files.filter { $0.pathExtension == "csv" }
    }
    
    func deleteExportedFile(_ fileURL: URL) async throws {
        try fileManager.removeItem(at: fileURL)
    }
    
    private func getExportDirectory() throws -> URL {
        let documentsDir = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let exportDir = documentsDir.appendingPathComponent("Exports")
        
        if !fileManager.fileExists(atPath: exportDir.path) {
            try fileManager.createDirectory(
                at: exportDir,
                withIntermediateDirectories: true
            )
        }
        
        return exportDir
    }
    
    private func parseCSVRow(_ row: String) -> [String] {
        var columns: [String] = []
        var currentColumn = ""
        var insideQuotes = false
        
        for char in row {
            switch char {
            case "\"":
                insideQuotes.toggle()
            case ",":
                if insideQuotes {
                    currentColumn.append(char)
                } else {
                    columns.append(currentColumn)
                    currentColumn = ""
                }
            default:
                currentColumn.append(char)
            }
        }
        
        if !currentColumn.isEmpty {
            columns.append(currentColumn)
        }
        
        return columns
    }
}

// MARK: - UIDocumentPickerDelegate
extension DataManagementService: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        
        // Check if this is an export or import operation
        if controller.allowsMultipleSelection {
            // This is an import operation
            Task {
                do {
                    try await restoreFromBackup(url)
                    // Notify success
                    NotificationCenter.default.post(name: .backupRestoredFromCloud, object: nil)
                } catch {
                    // Notify error
                    NotificationCenter.default.post(name: .backupError, object: error)
                }
            }
        } else {
            // This is an export operation
            do {
                try fileManager.copyItem(at: url, to: url)
                // Notify success
                NotificationCenter.default.post(name: .backupSavedToCloud, object: nil)
            } catch {
                // Notify error
                NotificationCenter.default.post(name: .backupError, object: error)
            }
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let backupSavedToCloud = Notification.Name("backupSavedToCloud")
    static let backupRestoredFromCloud = Notification.Name("backupRestoredFromCloud")
    static let backupError = Notification.Name("backupError")
    static let dataImportCompleted = Notification.Name("dataImportCompleted")
}

// MARK: - Date Formatter
private extension DateFormatter {
    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        return formatter
    }()
} 