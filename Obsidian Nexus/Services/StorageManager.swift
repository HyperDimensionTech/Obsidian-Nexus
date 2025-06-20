import Foundation

class StorageManager {
    static let shared = StorageManager()
    let itemRepository: ItemRepository
    let locationRepository: LocationRepository
    private let isbnMappingRepository: ISBNMappingRepository
    
    init(itemRepository: ItemRepository = SQLiteItemRepository(),
         locationRepository: LocationRepository = SQLiteLocationRepository(),
         isbnMappingRepository: ISBNMappingRepository = SQLiteISBNMappingRepository()) {
        self.itemRepository = itemRepository
        self.locationRepository = locationRepository
        self.isbnMappingRepository = isbnMappingRepository
    }
    
    // MARK: - ISBN Mapping Operations
    
    func getISBNMappingRepository() -> ISBNMappingRepository {
        return isbnMappingRepository
    }
    
    // MARK: - Item Operations
    
    func save(_ items: [InventoryItem]) throws {
        for item in items {
            try itemRepository.save(item)
        }
    }
    
    func save(_ item: InventoryItem) throws {
        do {
            try itemRepository.save(item)
        } catch let error as DatabaseManager.DatabaseError {
            throw error
        } catch {
            throw DatabaseManager.DatabaseError.insertFailed
        }
    }
    
    func update(_ item: InventoryItem) throws {
        do {
            try itemRepository.update(item)
        } catch let error as DatabaseManager.DatabaseError {
            throw error
        } catch {
            throw DatabaseManager.DatabaseError.updateFailed
        }
    }
    
    func deleteItem(_ item: InventoryItem) throws {
        do {
            try itemRepository.delete(item.id)
        } catch let error as DatabaseManager.DatabaseError {
            throw error
        } catch {
            throw DatabaseManager.DatabaseError.deleteFailed
        }
    }
    
    func loadItems() throws -> [InventoryItem] {
        print("StorageManager: Loading all items from database")
        do {
            let items = try itemRepository.fetchAll()
            print("StorageManager: Successfully loaded \(items.count) items")
            return items
        } catch let error as DatabaseManager.DatabaseError {
            print("StorageManager: Database error loading items: \(error.localizedDescription)")
            throw error
        } catch {
            print("StorageManager: Unknown error loading items: \(error.localizedDescription)")
            throw DatabaseManager.DatabaseError.invalidData
        }
    }
    
    func loadItems(ofType type: CollectionType) throws -> [InventoryItem] {
        try itemRepository.fetchByType(type)
    }
    
    func loadItems(inLocation locationId: UUID) throws -> [InventoryItem] {
        try itemRepository.fetchByLocation(locationId)
    }
    
    func loadTrashedItems() throws -> [InventoryItem] {
        try itemRepository.fetchDeletedItems()
    }
    
    func restoreItem(_ id: UUID) throws {
        try itemRepository.restoreItem(id)
    }
    
    func emptyTrash() throws {
        try itemRepository.emptyTrash()
    }
    
    func saveBatch(_ items: [InventoryItem]) throws {
        do {
            try itemRepository.saveBatch(items)
        } catch let error as DatabaseManager.DatabaseError {
            throw error
        } catch {
            throw DatabaseManager.DatabaseError.insertFailed
        }
    }
    
    func updateBatch(_ items: [InventoryItem]) throws {
        do {
            try itemRepository.updateBatch(items)
        } catch let error as DatabaseManager.DatabaseError {
            throw error
        } catch {
            throw DatabaseManager.DatabaseError.updateFailed
        }
    }
    
    // MARK: - Location Operations
    
    func save(_ location: StorageLocation) throws {
        try locationRepository.save(location)
    }
    
    func update(_ location: StorageLocation) throws {
        try locationRepository.update(location)
    }
    
    func deleteLocation(_ locationId: UUID) throws {
        // Check if location has items
        let items = try itemRepository.fetchByLocation(locationId)
        guard items.isEmpty else {
            throw LocationError.invalidOperation("Cannot delete location that contains items")
        }
        
        try locationRepository.delete(locationId)
    }
    
    func loadLocations() throws -> [StorageLocation] {
        try locationRepository.fetchAll()
    }
    
    func loadLocation(_ id: UUID) throws -> StorageLocation? {
        try locationRepository.fetchById(id)
    }
    
    func loadLocation(withId id: UUID) async throws -> StorageLocation? {
        try await Task {
            try locationRepository.fetchById(id)
        }.value
    }
    
    func loadChildren(of parentId: UUID) throws -> [StorageLocation] {
        try locationRepository.fetchChildren(of: parentId)
    }
    
    func updateLocationName(_ locationId: UUID, newName: String) throws {
        // Update the database
        try locationRepository.updateName(locationId, newName: newName)
    }
    
    // MARK: - Database Management
    
    func clear() throws {
        // Implementation note: This is a destructive operation that should be used carefully
        let dropTables = [
            "DELETE FROM items WHERE 1=1;",
            "DELETE FROM locations WHERE 1=1;",
            "DELETE FROM custom_fields WHERE 1=1;"
        ]
        
        for sql in dropTables {
            try DatabaseManager.shared.executeStatement(sql)
        }
    }

    func deleteItem(_ id: UUID) throws {
        try itemRepository.delete(id)
    }

    func updateLocationParent(_ locationId: UUID, newParentId: UUID) throws {
        // Update the database
        try locationRepository.updateParent(locationId, newParentId: newParentId)
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
        return itemRepository.classifyItem(title: title, publisher: publisher, description: description)
    }
} 