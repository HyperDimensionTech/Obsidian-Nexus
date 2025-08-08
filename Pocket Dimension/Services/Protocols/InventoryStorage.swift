import Foundation

// MARK: - Inventory Storage Abstraction

public protocol InventoryStorage {
    // General
    func debugDataCounts()
    func verifyDatabaseState()

    // Transactions
    func beginTransaction() throws
    func commitTransaction() throws

    // Items
    func loadItems() throws -> [InventoryItem]
    func loadTrashedItems() throws -> [InventoryItem]
    func save(_ item: InventoryItem) throws
    func save(_ items: [InventoryItem]) throws
    func saveBatch(_ items: [InventoryItem]) throws
    func update(_ item: InventoryItem) throws
    func deleteItem(_ id: UUID) throws
    func restoreItem(_ id: UUID) throws
    func emptyTrash() throws

    // Classification
    func classifyItem(title: String, publisher: String?, description: String?) -> CollectionType

    // Locations
    func loadLocations() throws -> [StorageLocation]
    func loadLocation(byId id: UUID) throws -> StorageLocation?
    func save(_ location: StorageLocation) throws
    func update(_ location: StorageLocation) throws
    func deleteLocation(_ id: UUID) throws
    func updateLocationName(_ id: UUID, newName: String) throws
    func updateLocationParent(_ id: UUID, newParentId: UUID?) throws
}


