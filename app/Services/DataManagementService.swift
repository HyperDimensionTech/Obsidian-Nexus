// MARK: - Import/Export
extension DataManagementService {
    func exportData() async throws -> URL {
        let items = try await storage.loadItems()
        let locations = try await storage.locationRepository.fetchAll()
        
        // Create CSV content
        var csvContent = "Title,Type,Series,Author,Publisher,ISBN,Price,Currency,PurchaseDate,Condition,Location,Synopsis\n"
        
        for item in items {
            let location = locations.first { $0.id == item.locationId }?.name ?? ""
            let priceString = item.price?.csvValue ?? ","
            let purchaseDate = item.purchaseDate?.formatted(date: .numeric, time: .omitted) ?? ""
            
            let row = [
                item.title,
                item.type.rawValue,
                item.series ?? "",
                item.author ?? "",
                item.publisher ?? "",
                item.isbn ?? "",
                priceString,
                purchaseDate,
                item.condition.rawValue,
                location,
                item.synopsis ?? ""
            ].map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\""
            }.joined(separator: ",")
            
            csvContent += row + "\n"
        }
        
        // Create export directory if it doesn't exist
        let exportDir = try getExportDirectory()
        
        // Create unique filename with timestamp
        let timestamp = Date().formatted(date: .numeric, time: .omitted)
            .replacingOccurrences(of: "/", with: "-")
        let filename = "inventory_export_\(timestamp).csv"
        let fileURL = exportDir.appendingPathComponent(filename)
        
        // Write CSV content
        try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
        
        return fileURL
    }
    
    func importData(from fileURL: URL) async throws {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let rows = content.components(separatedBy: .newlines)
        
        // Skip header row
        guard rows.count > 1 else { return }
        
        for row in rows.dropFirst() {
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
            let purchaseDate = DateFormatter.numeric.date(from: columns[8])
            
            // Create item
            let item = InventoryItem(
                title: columns[0],
                type: CollectionType(rawValue: columns[1]) ?? .books,
                series: columns[2].isEmpty ? nil : columns[2],
                author: columns[3].isEmpty ? nil : columns[3],
                publisher: columns[4].isEmpty ? nil : columns[4],
                isbn: columns[5].isEmpty ? nil : columns[5],
                price: price,
                purchaseDate: purchaseDate,
                condition: ItemCondition(rawValue: columns[9]) ?? .new,
                locationId: nil, // Will be set after location is created/found
                synopsis: columns[11].isEmpty ? nil : columns[11]
            )
            
            // Handle location
            if !columns[10].isEmpty {
                if let location = try await storage.locationRepository.fetchByName(columns[10]) {
                    try await storage.save(item)
                } else {
                    let newLocation = try await storage.locationRepository.create(
                        name: columns[10],
                        type: .shelf,
                        parentId: nil
                    )
                    try await storage.save(item)
                }
            } else {
                try await storage.save(item)
            }
        }
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

// MARK: - Date Formatter
private extension DateFormatter {
    static let numeric: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .numeric
        return formatter
    }()
} 