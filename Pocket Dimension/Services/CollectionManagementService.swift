import Foundation

/// Service responsible for managing collections, bulk operations, and item organization
@MainActor
class CollectionManagementService {
    
    // MARK: - Bulk Operations
    
    /// Update multiple items with the same field values
    func bulkUpdateItems(
        items: [InventoryItem], 
        updates: InventoryItem, 
        fields: Set<String>,
        storage: StorageManager
    ) throws -> [InventoryItem] {
        
        var updatedItems: [InventoryItem] = []
        
        for item in items {
            let updatedItem = try applyBulkUpdates(to: item, with: updates, fields: fields)
            updatedItems.append(updatedItem)
        }
        
        // Save to storage
        try storage.updateBatch(updatedItems)
        
        return updatedItems
    }
    
    /// Delete multiple items by their IDs
    func bulkDeleteItems(with ids: Set<UUID>, from items: inout [InventoryItem], storage: StorageManager) throws {
        for id in ids {
            try storage.deleteItem(id)
        }
        
        items.removeAll { ids.contains($0.id) }
    }
    
    /// Update location for multiple items
    func updateItemLocations(
        itemIds: Set<UUID>, 
        to locationId: UUID, 
        items: inout [InventoryItem], 
        locationManager: LocationManager,
        storage: StorageManager
    ) throws {
        
        guard locationManager.getLocation(by: locationId) != nil else {
            throw CollectionError.locationNotFound(locationId)
        }
        
        var updatedItems: [InventoryItem] = []
        
        for item in items {
            if itemIds.contains(item.id) {
                let updatedItem = updateInventoryItem(item, locationId: locationId)
                updatedItems.append(updatedItem)
                
                // Update in array
                if let index = items.firstIndex(where: { $0.id == item.id }) {
                    items[index] = updatedItem
                }
            }
        }
        
        // Save to storage
        try storage.updateBatch(updatedItems)
    }
    
    /// Update collection type for an item
    func updateItemType(
        _ item: InventoryItem, 
        newType: CollectionType, 
        items: inout [InventoryItem], 
        storage: StorageManager
    ) throws -> InventoryItem {
        
        let updatedItem = updateInventoryItem(item, type: newType)
        
        // Update in array
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = updatedItem
        }
        
        // Save to storage
        try storage.update(updatedItem)
        
        return updatedItem
    }
    
    /// Bulk update collection type for multiple items
    func bulkUpdateType(
        items itemsToUpdate: [InventoryItem], 
        newType: CollectionType, 
        allItems: inout [InventoryItem], 
        storage: StorageManager
    ) throws {
        
        for item in itemsToUpdate {
            _ = try updateItemType(item, newType: newType, items: &allItems, storage: storage)
        }
    }
    
    // MARK: - Batch Operations
    
    /// Add multiple items in a batch operation
    func addBatchItems(
        _ newItems: [InventoryItem], 
        to items: inout [InventoryItem], 
        storage: StorageManager,
        validationService: InventoryValidationService
    ) throws {
        
        var validatedItems: [InventoryItem] = []
        
        for item in newItems {
            // Validate each item against existing items
            let validatedItem = try validationService.validateAndSanitizeItem(
                item, 
                existingItems: items + validatedItems
            )
            validatedItems.append(validatedItem)
        }
        
        // Save all items to storage
        try storage.saveBatch(validatedItems)
        items.append(contentsOf: validatedItems)
    }
    
    // MARK: - Location Management
    
    /// Handle location removal by updating affected items
    func handleLocationRemoval(
        _ locationId: UUID, 
        items: inout [InventoryItem], 
        storage: StorageManager
    ) {
        
        var updatedItems: [InventoryItem] = []
        
        for item in items {
            if item.locationId == locationId {
                let updatedItem = updateInventoryItem(item, removeLocation: true)
                updatedItems.append(updatedItem)
                
                // Update in array
                if let index = items.firstIndex(where: { $0.id == item.id }) {
                    items[index] = updatedItem
                }
            }
        }
        
        // Save updated items to storage
        do {
            try storage.updateBatch(updatedItems)
        } catch {
            print("Error updating items after location removal: \(error)")
        }
    }
    
    /// Handle location rename by updating affected items
    func handleLocationRename(
        _ locationId: UUID, 
        newName: String, 
        items: inout [InventoryItem], 
        locationManager: LocationManager,
        storage: StorageManager
    ) {
        
        // Items don't store location names directly, so no update needed
        // This method exists for interface compatibility
    }
    
    /// Update individual item location
    func updateItemLocation(
        _ item: InventoryItem, 
        to locationId: UUID?, 
        items: inout [InventoryItem], 
        locationManager: LocationManager,
        storage: StorageManager
    ) {
        
        let updatedItem = updateInventoryItem(item, locationId: locationId)
        
        // Update in array
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = updatedItem
        }
        
        // Save to storage
        do {
            try storage.update(updatedItem)
        } catch {
            print("Error updating item location: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Helper method to create an updated InventoryItem with specific field changes
    private func updateInventoryItem(
        _ item: InventoryItem,
        type: CollectionType? = nil,
        locationId: UUID? = nil,
        removeLocation: Bool = false
    ) -> InventoryItem {
        
        let newLocationId = removeLocation ? nil : (locationId ?? item.locationId)
        
        return InventoryItem(
            title: item.title,
            type: type ?? item.type,
            series: item.series,
            volume: item.volume,
            condition: item.condition,
            locationId: newLocationId,
            notes: item.notes,
            id: item.id,
            dateAdded: item.dateAdded,
            barcode: item.barcode,
            thumbnailURL: item.thumbnailURL,
            author: item.author,
            manufacturer: item.manufacturer,
            originalPublishDate: item.originalPublishDate,
            publisher: item.publisher,
            isbn: item.isbn,
            price: item.price,
            purchaseDate: item.purchaseDate,
            synopsis: item.synopsis,
            customImageData: item.customImageData,
            imageSource: item.imageSource,
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
    }
    
    private func applyBulkUpdates(
        to item: InventoryItem, 
        with updates: InventoryItem, 
        fields: Set<String>
    ) throws -> InventoryItem {
        
        return InventoryItem(
            title: fields.contains("title") ? updates.title : item.title,
            type: fields.contains("type") ? updates.type : item.type,
            series: fields.contains("series") ? updates.series : item.series,
            volume: fields.contains("volume") ? updates.volume : item.volume,
            condition: fields.contains("condition") ? updates.condition : item.condition,
            locationId: fields.contains("locationId") ? updates.locationId : item.locationId,
            notes: fields.contains("notes") ? updates.notes : item.notes,
            id: item.id,
            dateAdded: item.dateAdded,
            barcode: fields.contains("barcode") ? updates.barcode : item.barcode,
            thumbnailURL: fields.contains("thumbnailURL") ? updates.thumbnailURL : item.thumbnailURL,
            author: fields.contains("author") ? updates.author : item.author,
            manufacturer: fields.contains("manufacturer") ? updates.manufacturer : item.manufacturer,
            originalPublishDate: fields.contains("originalPublishDate") ? updates.originalPublishDate : item.originalPublishDate,
            publisher: fields.contains("publisher") ? updates.publisher : item.publisher,
            isbn: fields.contains("isbn") ? updates.isbn : item.isbn,
            price: fields.contains("price") ? updates.price : item.price,
            purchaseDate: fields.contains("purchaseDate") ? updates.purchaseDate : item.purchaseDate,
            synopsis: fields.contains("synopsis") ? updates.synopsis : item.synopsis,
            customImageData: fields.contains("customImageData") ? updates.customImageData : item.customImageData,
            imageSource: fields.contains("imageSource") ? updates.imageSource : item.imageSource,
            serialNumber: fields.contains("serialNumber") ? updates.serialNumber : item.serialNumber,
            modelNumber: fields.contains("modelNumber") ? updates.modelNumber : item.modelNumber,
            character: fields.contains("character") ? updates.character : item.character,
            franchise: fields.contains("franchise") ? updates.franchise : item.franchise,
            dimensions: fields.contains("dimensions") ? updates.dimensions : item.dimensions,
            weight: fields.contains("weight") ? updates.weight : item.weight,
            releaseDate: fields.contains("releaseDate") ? updates.releaseDate : item.releaseDate,
            limitedEditionNumber: fields.contains("limitedEditionNumber") ? updates.limitedEditionNumber : item.limitedEditionNumber,
            hasOriginalPackaging: fields.contains("hasOriginalPackaging") ? updates.hasOriginalPackaging : item.hasOriginalPackaging,
            platform: fields.contains("platform") ? updates.platform : item.platform,
            developer: fields.contains("developer") ? updates.developer : item.developer,
            genre: fields.contains("genre") ? updates.genre : item.genre,
            ageRating: fields.contains("ageRating") ? updates.ageRating : item.ageRating,
            technicalSpecs: fields.contains("technicalSpecs") ? updates.technicalSpecs : item.technicalSpecs,
            warrantyExpiry: fields.contains("warrantyExpiry") ? updates.warrantyExpiry : item.warrantyExpiry
        )
    }
    
    // MARK: - Error Types
    
    enum CollectionError: LocalizedError {
        case locationNotFound(UUID)
        case bulkOperationFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .locationNotFound(let id):
                return "Location with ID \(id) not found"
            case .bulkOperationFailed(let reason):
                return "Bulk operation failed: \(reason)"
            }
        }
    }
} 