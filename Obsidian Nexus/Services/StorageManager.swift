import Foundation

class StorageManager {
    static let shared = StorageManager()
    let itemRepository: ItemRepository
    let locationRepository: LocationRepository
    
    init(itemRepository: ItemRepository = SQLiteItemRepository(),
         locationRepository: LocationRepository = SQLiteLocationRepository()) {
        self.itemRepository = itemRepository
        self.locationRepository = locationRepository
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
        try itemRepository.fetchAll()
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
    
    func loadChildren(of parentId: UUID) throws -> [StorageLocation] {
        try locationRepository.fetchChildren(of: parentId)
    }
    
    func updateLocationName(_ locationId: UUID, newName: String) throws {
        // Update the database
        try locationRepository.updateName(locationId, newName: newName)
    }
    
    // MARK: - Database Management
    
    func clear() {
        // Implementation note: This is a destructive operation that should be used carefully
        let dropTables = [
            "DELETE FROM items WHERE 1=1;",
            "DELETE FROM locations WHERE 1=1;",
            "DELETE FROM custom_fields WHERE 1=1;"
        ]
        
        for sql in dropTables {
            DatabaseManager.shared.executeStatement(sql)
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