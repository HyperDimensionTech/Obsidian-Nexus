import Foundation

struct SearchOptions {
    var query: String = ""
    var types: Set<CollectionType> = []
    var location: StorageLocation? = nil
    var condition: ItemCondition? = nil
    
    var hasFilters: Bool {
        !types.isEmpty || location != nil || condition != nil
    }
    
    func matches(_ item: InventoryItem, locationManager: LocationManager) -> Bool {
        // Title match
        if !query.isEmpty {
            let lowercasedQuery = query.lowercased()
            guard item.title.lowercased().contains(lowercasedQuery) else {
                return false
            }
        }
        
        // Type match
        if !types.isEmpty && !types.contains(item.type) {
            return false
        }
        
        // Location match
        if let searchLocation = location {
            guard let itemLocationId = item.locationId,
                  let itemLocation = locationManager.location(withId: itemLocationId),
                  itemLocation.id == searchLocation.id else {
                return false
            }
        }
        
        // Match condition
        if let searchCondition = condition {
            if item.condition != searchCondition {
                return false
            }
        }
        
        return true
    }
} 