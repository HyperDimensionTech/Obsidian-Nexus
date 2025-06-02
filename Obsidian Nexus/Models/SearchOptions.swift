import Foundation

struct SearchOptions {
    var query: String = ""
    var types: Set<CollectionType> = []
    var location: StorageLocation? = nil
    var condition: ItemCondition? = nil
    var showSeriesOnly: Bool = false
    var incompleteSeriesOnly: Bool = false
    var seriesGrouping: SeriesGroupingStyle = .none
    
    enum SeriesGroupingStyle {
        case none
        case bySeries
        case byAuthor
        
        var displayName: String {
            switch self {
            case .none: return "None"
            case .bySeries: return "By Series"
            case .byAuthor: return "By Author"
            }
        }
    }
    
    var hasFilters: Bool {
        !types.isEmpty || location != nil || condition != nil || showSeriesOnly || incompleteSeriesOnly
    }
    
    @MainActor
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