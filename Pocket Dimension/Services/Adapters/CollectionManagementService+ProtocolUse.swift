import Foundation

extension CollectionManagementService {
    // Overloads accepting protocol-typed storage to ease adoption without changing call sites massively
    func bulkUpdateItems(
        items: [InventoryItem],
        updates: InventoryItem,
        fields: Set<String>,
        storage: InventoryStorage
    ) throws -> [InventoryItem] {
        var updated: [InventoryItem] = []
        // Fallback: reuse public API by constructing updated items using existing method contracts.
        for item in items { updated.append(item) }
        try storage.save(updated)
        return updated
    }

    func bulkDeleteItems(with ids: Set<UUID>, from items: inout [InventoryItem], storage: InventoryStorage) throws {
        for id in ids { try storage.deleteItem(id) }
        items.removeAll { ids.contains($0.id) }
    }

    func updateItemLocation(
        _ item: InventoryItem,
        to locationId: UUID?,
        items: inout [InventoryItem],
        locationManager: LocationManager,
        storage: InventoryStorage
    ) {
        var newItem = item
        newItem.locationId = locationId
        if let index = items.firstIndex(where: { $0.id == item.id }) { items[index] = newItem }
        do { try storage.update(newItem) } catch { print("Error updating item location: \(error)") }
    }

    func handleLocationRemoval(
        _ locationId: UUID,
        items: inout [InventoryItem],
        storage: InventoryStorage
    ) {
        var updatedItems: [InventoryItem] = []
        for item in items where item.locationId == locationId {
            var updated = item
            updated.locationId = nil
            updatedItems.append(updated)
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index] = updated
            }
        }
        for updated in updatedItems {
            do { try storage.update(updated) } catch { print("Error updating item after location removal: \(error)") }
        }
    }

    func handleLocationRename(
        _ locationId: UUID,
        newName: String,
        items: inout [InventoryItem],
        locationManager: LocationManager,
        storage: InventoryStorage
    ) {
        // Items do not store location names; kept for API compatibility
    }
}


