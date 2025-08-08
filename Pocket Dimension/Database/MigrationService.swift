import Foundation
import SQLite3

// MARK: - Exported Data Structures
public struct ExportedData {
    let items: [LegacyInventoryItem]
    let locations: [LegacyStorageLocation]
    
    var isEmpty: Bool {
        return items.isEmpty && locations.isEmpty
    }
}

public struct LegacyInventoryItem {
    let id: String
    let title: String
    let type: String
    let series: String?
    let volume: Int?
    let condition: String
    let locationId: String?
    let notes: String?
    let barcode: String?
    let thumbnailURL: String?
    let author: String?
    let manufacturer: String?
    let originalPublishDate: Date?
    let publisher: String?
    let isbn: String?
    let priceAmount: Decimal?
    let priceCurrency: String?
    let purchaseDate: Date?
    let synopsis: String?
    let createdAt: Date
    let updatedAt: Date
    
    // Add all v3 fields to prevent data loss
    let customImageData: Data?
    let imageSource: String?
    let serialNumber: String?
    let modelNumber: String?
    let character: String?
    let franchise: String?
    let dimensions: String?
    let weight: String?
    let releaseDate: Date?
    let limitedEditionNumber: String?
    let hasOriginalPackaging: Bool?
    let platform: String?
    let developer: String?
    let genre: String?
    let ageRating: String?
    let technicalSpecs: String?
    let warrantyExpiry: Date?
}

public struct LegacyStorageLocation {
    let id: String
    let name: String
    let type: String
    let parentId: String?
    let createdAt: Date
    let updatedAt: Date
}

// MARK: - Migration Service Extension for DatabaseManager
extension DatabaseManager {
    
    // MARK: - Export Legacy Data
    
    func exportLegacyData() throws -> ExportedData {
        print("🔹 MIGRATION 🔹 Starting data export...")
        
        let items = try exportInventoryItems()
        let locations = try exportStorageLocations()
        
        print("🔹 MIGRATION 🔹 Export complete: \(items.count) items, \(locations.count) locations")
        
        return ExportedData(items: items, locations: locations)
    }
    
    private func exportInventoryItems() throws -> [LegacyInventoryItem] {
        // Check if items table exists
        let itemsExists = executeScalar("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='items';") > 0
        
        if !itemsExists {
            print("🔹 MIGRATION 🔹 No items table found, returning empty array")
            return []
        }
        
        let sql = """
            SELECT id, title, type, series, volume, condition, location_id, notes, 
                   barcode, thumbnail_url, author, manufacturer, original_publish_date,
                   publisher, isbn, price, purchase_date, synopsis, created_at, updated_at,
                   custom_image_data, image_source, serial_number, model_number, character,
                   franchise, dimensions, weight, release_date, limited_edition_number,
                   has_original_packaging, platform, developer, genre, age_rating,
                   technical_specs, warranty_expiry
            FROM items 
            WHERE deleted_at IS NULL
            ORDER BY created_at ASC;
        """
        
        var items: [LegacyInventoryItem] = []
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(connection, sql, -1, &statement, nil) == SQLITE_OK else {
            let error = String(cString: sqlite3_errmsg(connection))
            print("🔹 MIGRATION 🔹 Failed to prepare items query: \(error)")
            throw DatabaseError.prepareFailed(error)
        }
        
        defer { sqlite3_finalize(statement) }
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let item = LegacyInventoryItem(
                id: String(cString: sqlite3_column_text(statement, 0)),
                title: String(cString: sqlite3_column_text(statement, 1)),
                type: String(cString: sqlite3_column_text(statement, 2)),
                series: sqlite3_column_text(statement, 3).map { String(cString: $0) },
                volume: sqlite3_column_int(statement, 4) > 0 ? Int(sqlite3_column_int(statement, 4)) : nil,
                condition: String(cString: sqlite3_column_text(statement, 5)),
                locationId: sqlite3_column_text(statement, 6).map { String(cString: $0) },
                notes: sqlite3_column_text(statement, 7).map { String(cString: $0) },
                barcode: sqlite3_column_text(statement, 8).map { String(cString: $0) },
                thumbnailURL: sqlite3_column_text(statement, 9).map { String(cString: $0) },
                author: sqlite3_column_text(statement, 10).map { String(cString: $0) },
                manufacturer: sqlite3_column_text(statement, 11).map { String(cString: $0) },
                originalPublishDate: sqlite3_column_int64(statement, 12) > 0 ? Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 12))) : nil,
                publisher: sqlite3_column_text(statement, 13).map { String(cString: $0) },
                isbn: sqlite3_column_text(statement, 14).map { String(cString: $0) },
                priceAmount: sqlite3_column_double(statement, 15) > 0 ? Decimal(sqlite3_column_double(statement, 15)) : nil,
                priceCurrency: "USD", // Default currency for legacy items
                purchaseDate: sqlite3_column_int64(statement, 16) > 0 ? Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 16))) : nil,
                synopsis: sqlite3_column_text(statement, 17).map { String(cString: $0) },
                createdAt: Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 18))),
                updatedAt: Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 19))),
                
                // Extract v3 fields
                customImageData: {
                    if let blob = sqlite3_column_blob(statement, 20) {
                        let length = sqlite3_column_bytes(statement, 20)
                        return Data(bytes: blob, count: Int(length))
                    }
                    return nil
                }(),
                imageSource: sqlite3_column_text(statement, 21).map { String(cString: $0) },
                serialNumber: sqlite3_column_text(statement, 22).map { String(cString: $0) },
                modelNumber: sqlite3_column_text(statement, 23).map { String(cString: $0) },
                character: sqlite3_column_text(statement, 24).map { String(cString: $0) },
                franchise: sqlite3_column_text(statement, 25).map { String(cString: $0) },
                dimensions: sqlite3_column_text(statement, 26).map { String(cString: $0) },
                weight: sqlite3_column_text(statement, 27).map { String(cString: $0) },
                releaseDate: sqlite3_column_int64(statement, 28) > 0 ? Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 28))) : nil,
                limitedEditionNumber: sqlite3_column_text(statement, 29).map { String(cString: $0) },
                hasOriginalPackaging: sqlite3_column_int(statement, 30) > 0 ? (sqlite3_column_int(statement, 30) == 1) : nil,
                platform: sqlite3_column_text(statement, 31).map { String(cString: $0) },
                developer: sqlite3_column_text(statement, 32).map { String(cString: $0) },
                genre: sqlite3_column_text(statement, 33).map { String(cString: $0) },
                ageRating: sqlite3_column_text(statement, 34).map { String(cString: $0) },
                technicalSpecs: sqlite3_column_text(statement, 35).map { String(cString: $0) },
                warrantyExpiry: sqlite3_column_int64(statement, 36) > 0 ? Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 36))) : nil
            )
            
            items.append(item)
        }
        
        print("🔹 MIGRATION 🔹 Exported \(items.count) inventory items from items table")
        return items
    }
    
    private func exportStorageLocations() throws -> [LegacyStorageLocation] {
        // Check which table exists - legacy databases might have storage_locations instead of locations
        let storageLocationsExists = executeScalar("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='storage_locations';") > 0
        let locationsExists = executeScalar("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='locations';") > 0
        
        let tableName = storageLocationsExists ? "storage_locations" : "locations"
        
        if !storageLocationsExists && !locationsExists {
            print("🔹 MIGRATION 🔹 No locations table found, returning empty array")
            return []
        }
        
        let sql = """
            SELECT id, name, type, parent_id, created_at, updated_at
            FROM \(tableName)
            WHERE deleted_at IS NULL
            ORDER BY created_at ASC;
        """
        
        var locations: [LegacyStorageLocation] = []
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(connection, sql, -1, &statement, nil) == SQLITE_OK else {
            let error = String(cString: sqlite3_errmsg(connection))
            print("🔹 MIGRATION 🔹 Failed to prepare locations query: \(error)")
            throw DatabaseError.prepareFailed(error)
        }
        
        defer { sqlite3_finalize(statement) }
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let location = LegacyStorageLocation(
                id: String(cString: sqlite3_column_text(statement, 0)),
                name: String(cString: sqlite3_column_text(statement, 1)),
                type: String(cString: sqlite3_column_text(statement, 2)),
                parentId: sqlite3_column_text(statement, 3).map { String(cString: $0) },
                createdAt: Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 4))),
                updatedAt: Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 5)))
            )
            
            locations.append(location)
        }
        
        print("🔹 MIGRATION 🔹 Exported \(locations.count) storage locations from \(tableName) table")
        return locations
    }
    
    // MARK: - Import as Events
    
    func importDataAsEvents(_ data: ExportedData) throws {
        print("🔹 MIGRATION 🔹 Converting exported data to CRDT events...")
        
        let deviceId = DeviceID()
        var vectorClock = VectorClock()
        let eventStore = EventStore(database: self)
        
        try beginTransaction()
        
        do {
            // Import locations first (they're referenced by items)
            for location in data.locations {
                vectorClock.increment(for: deviceId)
                
                let event = LocationCreated(
                    aggregateId: UUID(uuidString: location.id) ?? UUID(),
                    deviceId: deviceId,
                    version: 1,
                    name: location.name,
                    type: location.type,
                    parentId: location.parentId.flatMap { UUID(uuidString: $0) }
                )
                
                try eventStore.saveEvent(LocationEvent.created(event))
                print("🔹 MIGRATION 🔹 Migrated location: \(location.name)")
            }
            
            // Import inventory items
            for item in data.items {
                vectorClock.increment(for: deviceId)
                
                let event = InventoryItemCreated(
                    aggregateId: UUID(uuidString: item.id) ?? UUID(),
                    deviceId: deviceId,
                    version: 1,
                    title: item.title,
                    type: item.type,
                    series: item.series,
                    volume: item.volume,
                    condition: item.condition,
                    locationId: item.locationId.flatMap { UUID(uuidString: $0) },
                    notes: item.notes,
                    dateAdded: item.createdAt,
                    barcode: item.barcode,
                    thumbnailURL: item.thumbnailURL,
                    author: item.author,
                    manufacturer: item.manufacturer,
                    originalPublishDate: item.originalPublishDate,
                    publisher: item.publisher,
                    isbn: item.isbn,
                    price: item.priceAmount,
                    priceCurrency: item.priceCurrency,
                    purchaseDate: item.purchaseDate,
                    synopsis: item.synopsis,
                    customImageData: item.customImageData,
                    imageSource: item.imageSource ?? "none",
                    serialNumber: item.serialNumber,
                    modelNumber: item.modelNumber,
                    character: item.character,
                    franchise: item.franchise,
                    dimensions: item.dimensions,
                    weight: item.weight,
                    releaseDate: item.releaseDate,
                    limitedEditionNumber: item.limitedEditionNumber,
                    hasOriginalPackaging: item.hasOriginalPackaging,
                    platform: item.platform,
                    developer: item.developer,
                    genre: item.genre,
                    ageRating: item.ageRating,
                    technicalSpecs: item.technicalSpecs,
                    warrantyExpiry: item.warrantyExpiry
                )
                
                try eventStore.saveEvent(InventoryItemEvent.created(event))
                print("🔹 MIGRATION 🔹 Migrated item: \(item.title)")
            }
            
            try commitTransaction()
            print("🔹 MIGRATION 🔹 Successfully imported all data as events")
            
        } catch {
            try? rollbackTransaction()
            print("🔹 MIGRATION 🔹 Failed to import data: \(error)")
            throw error
        }
    }
    
    // MARK: - JSON Export for Backup
    
    func exportToJSON() throws -> Data {
        let data = try exportLegacyData()
        
        let export = [
            "version": DatabaseSchema.crdtVersion,
            "timestamp": Int(Date().timeIntervalSince1970),
            "device_id": DeviceID().uuid,
            "items": data.items.map { item in
                [
                    "id": item.id,
                    "title": item.title,
                    "type": item.type,
                    "series": item.series as Any,
                    "volume": item.volume as Any,
                    "condition": item.condition,
                    "location_id": item.locationId as Any,
                    "notes": item.notes as Any,
                    "barcode": item.barcode as Any,
                    "thumbnail_url": item.thumbnailURL as Any,
                    "author": item.author as Any,
                    "manufacturer": item.manufacturer as Any,
                    "original_publish_date": item.originalPublishDate?.timeIntervalSince1970 as Any,
                    "publisher": item.publisher as Any,
                    "isbn": item.isbn as Any,
                    "price_amount": item.priceAmount?.description as Any,
                    "purchase_date": item.purchaseDate?.timeIntervalSince1970 as Any,
                    "synopsis": item.synopsis as Any,
                    "created_at": item.createdAt.timeIntervalSince1970,
                    "updated_at": item.updatedAt.timeIntervalSince1970
                ]
            },
            "locations": data.locations.map { location in
                [
                    "id": location.id,
                    "name": location.name,
                    "type": location.type,
                    "parent_id": location.parentId as Any,
                    "created_at": location.createdAt.timeIntervalSince1970,
                    "updated_at": location.updatedAt.timeIntervalSince1970
                ]
            }
        ] as [String: Any]
        
        return try JSONSerialization.data(withJSONObject: export, options: .prettyPrinted)
    }
} 