import Foundation

class StorageManager {
    static let shared = StorageManager()
    private var crdtRepository: CRDTRepository
    
    init(crdtRepository: CRDTRepository = CRDTRepository()) {
        self.crdtRepository = crdtRepository
    }
    
    // MARK: - ISBN Mapping Operations
    
    func loadISBNMappings() throws -> [ISBNMapping] {
        return crdtRepository.getISBNMappings()
    }
    
    func getISBNMapping(for isbn: String) -> ISBNMapping? {
        return crdtRepository.getISBNMapping(for: isbn)
    }
    
    func createISBNMapping(
        incorrectISBN: String,
        correctGoogleBooksID: String,
        title: String,
        isReprint: Bool = true
    ) throws {
        try crdtRepository.createISBNMapping(
            incorrectISBN: incorrectISBN,
            correctGoogleBooksID: correctGoogleBooksID,
            title: title,
            isReprint: isReprint
        )
    }
    
    func deleteISBNMapping(incorrectISBN: String) throws {
        try crdtRepository.deleteISBNMapping(incorrectISBN: incorrectISBN)
    }
    
    // MARK: - Item Operations
    
    func save(_ items: [InventoryItem]) throws {
        for item in items {
            try save(item)
        }
    }
    
    func save(_ item: InventoryItem) throws {
        // Use CRDT repository to create new item
        do {
            _ = try crdtRepository.createInventoryItem(
                title: item.title,
                type: item.type,
                series: item.series,
                volume: item.volume,
                condition: item.condition,
                locationId: item.locationId,
                notes: item.notes,
                dateAdded: item.dateAdded,
                barcode: item.barcode,
                author: item.author,
                publisher: item.publisher,
                isbn: item.isbn,
                price: item.price,
                synopsis: item.synopsis,
                thumbnailURL: item.thumbnailURL,
                customImageData: item.customImageData,
                imageSource: item.imageSource,
                // Additional v3 fields
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
        } catch let error as DatabaseManager.DatabaseError {
            throw error
        } catch {
            throw DatabaseManager.DatabaseError.insertFailed
        }
    }
    
    func update(_ item: InventoryItem) throws {
        // Use CRDT repository to update existing item
        do {
            var updates: [String: Any] = [:]
            
            // Build updates dictionary with basic fields
            updates["title"] = item.title
            updates["type"] = item.type.rawValue
            updates["condition"] = item.condition.rawValue
            
            if let series = item.series {
                updates["series"] = series
            }
            if let volume = item.volume {
                updates["volume"] = volume
            }
            if let locationId = item.locationId {
                updates["locationId"] = locationId.uuidString
            }
            if let notes = item.notes {
                updates["notes"] = notes
            }
            
            try crdtRepository.updateInventoryItem(id: item.id, updates: updates)
        } catch let error as DatabaseManager.DatabaseError {
            throw error
        } catch {
            throw DatabaseManager.DatabaseError.updateFailed
        }
    }
    
    func deleteItem(_ item: InventoryItem) throws {
        try deleteItem(item.id)
    }
    
    func deleteItem(_ id: UUID) throws {
        do {
            try crdtRepository.deleteInventoryItem(id: id)
        } catch let error as DatabaseManager.DatabaseError {
            throw error
        } catch {
            throw DatabaseManager.DatabaseError.deleteFailed
        }
    }
    
    func loadItems() throws -> [InventoryItem] {
        print("StorageManager: Loading items from CRDT repository")
        
        // Use CRDT repository only
        let crdtItems = crdtRepository.getInventoryItems()
        print("StorageManager: Successfully loaded \(crdtItems.count) items from CRDT repository")
        return crdtItems
    }
    
    func loadItems(ofType type: CollectionType) throws -> [InventoryItem] {
        // For now, use CRDT repository and filter by type
        let allItems = crdtRepository.getInventoryItems()
        return allItems.filter { $0.type == type }
    }
    
    func loadItems(inLocation locationId: UUID) throws -> [InventoryItem] {
        // For now, use CRDT repository and filter by location
        let allItems = crdtRepository.getInventoryItems()
        return allItems.filter { $0.locationId == locationId }
    }
    
    func loadTrashedItems() throws -> [InventoryItem] {
        // In CRDT system, we need to get deleted items from the repository
        // For now, return empty array since CRDT handles soft-deletes differently
        // In a full implementation, we'd need to track soft-deleted items
        return []
    }
    
    func restoreItem(_ id: UUID) throws {
        // In CRDT system, restore would involve creating an "undelete" event
        // For now, we'll create a new item with the same data
        // This is a simplified implementation - full CRDT would need proper event handling
        
        // Get the item from CRDT repository (this would include deleted items in full implementation)
        let allItems = crdtRepository.getInventoryItems()
        guard let itemToRestore = allItems.first(where: { $0.id == id }) else {
            throw DatabaseManager.DatabaseError.notFound
        }
        
        // Create a restore event by recreating the item
        // In a full CRDT implementation, this would be an "undelete" event
        _ = try crdtRepository.createInventoryItem(
            title: itemToRestore.title,
            type: itemToRestore.type,
            series: itemToRestore.series,
            volume: itemToRestore.volume,
            condition: itemToRestore.condition,
            locationId: itemToRestore.locationId,
            notes: itemToRestore.notes,
            dateAdded: itemToRestore.dateAdded,
            barcode: itemToRestore.barcode,
            author: itemToRestore.author,
            publisher: itemToRestore.publisher,
            isbn: itemToRestore.isbn,
            price: itemToRestore.price,
            synopsis: itemToRestore.synopsis,
            thumbnailURL: itemToRestore.thumbnailURL,
            customImageData: itemToRestore.customImageData,
            imageSource: itemToRestore.imageSource
        )
    }
    
    func emptyTrash() throws {
        // In CRDT system, deleted items are handled by event sourcing
        // Emptying trash would involve creating "permanently delete" events
        // For now, this is a no-op since CRDT soft-deletes don't need physical deletion
        // In a full implementation, we'd create permanent deletion events
        print("🔍 StorageManager: Empty trash - CRDT system handles deletion through events")
    }
    
    func saveBatch(_ items: [InventoryItem]) throws {
        // Use CRDT repository for batch save
        for item in items {
            try save(item)
        }
    }
    
    func updateBatch(_ items: [InventoryItem]) throws {
        // Use CRDT repository for batch update
        for item in items {
            try update(item)
        }
    }
    
    // MARK: - Location Operations
    
    func save(_ location: StorageLocation) throws {
        // Use CRDT repository to create new location
        do {
            _ = try crdtRepository.createLocation(
                name: location.name,
                type: location.type,
                parentId: location.parentId
            )
        } catch let error as DatabaseManager.DatabaseError {
            throw error
        } catch {
            throw DatabaseManager.DatabaseError.insertFailed
        }
    }
    
    func update(_ location: StorageLocation) throws {
        // Use CRDT repository to update existing location
        do {
            var updates: [String: Any] = [:]
            updates["name"] = location.name
            updates["type"] = location.type.rawValue
            
            if let parentId = location.parentId {
                updates["parentId"] = parentId.uuidString
            }
            
            try crdtRepository.updateLocation(id: location.id, updates: updates)
        } catch let error as DatabaseManager.DatabaseError {
            throw error
        } catch {
            throw DatabaseManager.DatabaseError.updateFailed
        }
    }
    
    func deleteLocation(_ location: StorageLocation) throws {
        try deleteLocation(location.id)
    }
    
    func deleteLocation(_ locationId: UUID) throws {
        do {
            try crdtRepository.deleteLocation(id: locationId)
        } catch let error as DatabaseManager.DatabaseError {
            throw error
        } catch {
            throw DatabaseManager.DatabaseError.deleteFailed
        }
    }
    
    func loadLocations() throws -> [StorageLocation] {
        // Use CRDT repository only
        let crdtLocations = crdtRepository.getStorageLocations()
        print("StorageManager: Successfully loaded \(crdtLocations.count) locations from CRDT repository")
        return crdtLocations
    }
    
    func loadLocation(byId id: UUID) throws -> StorageLocation? {
        // Use CRDT repository only
        let crdtLocations = crdtRepository.getStorageLocations()
        return crdtLocations.first(where: { $0.id == id })
    }
    
    func loadChildLocations(of parentId: UUID) throws -> [StorageLocation] {
        // Use CRDT repository to get all locations and filter by parent
        let allLocations = crdtRepository.getStorageLocations()
        return allLocations.filter { $0.parentId == parentId }
    }
    
    func updateLocationParent(_ locationId: UUID, newParentId: UUID?) throws {
        // Use CRDT repository to update location parent
        do {
            var updates: [String: Any] = [:]
            if let newParentId = newParentId {
                updates["parentId"] = newParentId.uuidString
            }
            
            try crdtRepository.updateLocation(id: locationId, updates: updates)
        } catch let error as DatabaseManager.DatabaseError {
            throw error
        } catch {
            throw DatabaseManager.DatabaseError.updateFailed
        }
    }
    
    func updateLocationName(_ locationId: UUID, newName: String) throws {
        // Use CRDT repository to update location name
        do {
            let updates: [String: Any] = ["name": newName]
            try crdtRepository.updateLocation(id: locationId, updates: updates)
        } catch let error as DatabaseManager.DatabaseError {
            throw error
        } catch {
            throw DatabaseManager.DatabaseError.updateFailed
        }
    }
    
    func verifyDatabaseState() {
        print("🔍 StorageManager: Verifying CRDT database state")
        debugDataCounts()
    }
    
    // MARK: - CRDT Access
    
    /// Get direct access to CRDT repository for advanced operations
    func getCRDTRepository() -> CRDTRepository {
        return crdtRepository
    }
    
    // MARK: - Debug Methods
    
    /// Debug method to show data counts from CRDT repository
    func debugDataCounts() {
        print("🔍 StorageManager Debug Info:")
        
        // CRDT repository counts
        let crdtItems = crdtRepository.getInventoryItems()
        let crdtLocations = crdtRepository.getStorageLocations()
        print("🔍 CRDT Repository: \(crdtItems.count) items, \(crdtLocations.count) locations")
        
        // Event store counts
        do {
            let eventStore = EventStore()
            let eventCount = try eventStore.getEventCount()
            print("🔍 Event Store: \(eventCount) events")
        } catch {
            print("🔍 Event Store: Error loading - \(error.localizedDescription)")
        }
    }
    
    // MARK: - Database Management
    
    func clear() throws {
        // For CRDT system, we need to clear the event store
        // This is a destructive operation that should be used carefully
        do {
            let eventStore = EventStore()
            // Delete all events older than now (effectively clearing everything)
            try eventStore.deleteEventsOlderThan(Date())
            
            // Reinitialize CRDT repository to reload cleared state
            crdtRepository = CRDTRepository()
        } catch {
            throw DatabaseManager.DatabaseError.transactionFailed(error.localizedDescription)
        }
    }



    func beginTransaction() throws {
        try DatabaseManager.shared.beginTransaction()
    }
    
    func commitTransaction() throws {
        try DatabaseManager.shared.commitTransaction()
    }
    
    func rollbackTransaction() throws {
        try DatabaseManager.shared.rollbackTransaction()
    }

    func classifyItem(title: String, publisher: String?, description: String?) -> CollectionType {
        // Temporarily disabled during migration - default to books
        return .books
    }
} 