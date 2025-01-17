import Foundation

class LocationManager: ObservableObject {
    @Published private(set) var locations: [UUID: StorageLocation] = [:]
    private weak var inventoryViewModel: InventoryViewModel?
    
    init(inventoryViewModel: InventoryViewModel? = nil) {
        self.inventoryViewModel = inventoryViewModel
    }
    
    // MARK: - Location Management
    
    func addLocation(_ location: StorageLocation) throws {
        try validateLocationAdd(location)
        
        if let parentId = location.parentId {
            guard var parent = locations[parentId] else {
                throw LocationError.parentNotFound
            }
            
            guard parent.addChild(location.id) else {
                throw LocationError.addChildFailed
            }
            
            locations[parentId] = parent
        }
        
        locations[location.id] = location
    }
    
    func addChildLocation(_ child: StorageLocation, to parentId: UUID) throws {
        guard let parent = locations[parentId] else {
            throw LocationError.parentNotFound
        }
        
        var updatedChild = child
        updatedChild.parentId = parentId
        
        guard parent.canAdd(childType: child.type) else {
            throw LocationError.invalidChildType
        }
        
        try addLocation(updatedChild)
    }
    
    func updateLocation(_ location: StorageLocation) throws {
        try validateLocationUpdate(location)
        
        let oldLocation = locations[location.id]
        
        // Handle parent changes
        if oldLocation?.parentId != location.parentId {
            // Remove from old parent
            if let oldParentId = oldLocation?.parentId,
               var oldParent = locations[oldParentId] {
                oldParent.removeChild(location.id)
                locations[oldParentId] = oldParent
            }
            
            // Add to new parent
            if let newParentId = location.parentId,
               var newParent = locations[newParentId] {
                guard newParent.addChild(location.id) else {
                    throw LocationError.addChildFailed
                }
                locations[newParentId] = newParent
            }
        }
        
        // Update the location
        locations[location.id] = location
        
        // Notify inventory view model of changes
        if oldLocation?.name != location.name {
            inventoryViewModel?.handleLocationRename(location.id, newName: location.name)
        }
    }
    
    func removeLocation(_ locationId: UUID) throws {
        guard let location = locations[locationId] else {
            throw LocationError.locationNotFound
        }
        
        // Check if location has items
        if inventoryViewModel?.hasItemsInLocation(locationId) == true {
            throw LocationError.invalidOperation("Cannot delete location that contains items")
        }
        
        // Remove from parent
        if let parentId = location.parentId {
            var parent = locations[parentId]
            parent?.removeChild(locationId)
            if let updatedParent = parent {
                locations[parentId] = updatedParent
            }
        }
        
        // Remove all children recursively
        for childId in location.childIds {
            try removeLocation(childId)
        }
        
        // Remove the location itself
        locations.removeValue(forKey: locationId)
        
        // Notify inventory view model
        inventoryViewModel?.handleLocationRemoval(locationId)
    }
    
    // MARK: - Hierarchy Queries
    
    func children(of locationId: UUID) -> [StorageLocation] {
        guard let location = locations[locationId] else { return [] }
        return location.childIds.compactMap { locations[$0] }
    }
    
    func descendants(of locationId: UUID) -> [StorageLocation] {
        var result: [StorageLocation] = []
        let directChildren = children(of: locationId)
        result.append(contentsOf: directChildren)
        
        for child in directChildren {
            result.append(contentsOf: descendants(of: child.id))
        }
        
        return result
    }
    
    func ancestors(of locationId: UUID) -> [StorageLocation] {
        var result: [StorageLocation] = []
        var currentId = locationId
        
        while let location = locations[currentId],
              let parentId = location.parentId {
            if let parent = locations[parentId] {
                result.append(parent)
                currentId = parentId
            } else {
                break
            }
        }
        
        return result
    }
    
    func path(to locationId: UUID) -> String {
        let ancestors = ancestors(of: locationId).reversed()
        let locationName = locations[locationId]?.name ?? ""
        return (ancestors.map { $0.name } + [locationName]).joined(separator: " > ")
    }
    
    func hierarchyString(for locationId: UUID, indent: String = "") -> String {
        guard let location = locations[locationId] else { return "" }
        
        var result = "\(indent)\(location.name) (\(location.type.rawValue))\n"
        for childId in location.childIds {
            result += hierarchyString(for: childId, indent: indent + "  ")
        }
        return result
    }
    
    // MARK: - Utility Methods
    
    func location(withId id: UUID) -> StorageLocation? {
        locations[id]
    }
    
    func allLocations() -> [StorageLocation] {
        Array(locations.values)
    }
    
    func locations(ofType type: StorageLocation.LocationType) -> [StorageLocation] {
        allLocations().filter { $0.type == type }
    }
    
    func rootLocations() -> [StorageLocation] {
        allLocations().filter { $0.parentId == nil }
    }
    
    func loadSampleData() {
        // Create main locations
        let livingRoom = StorageLocation(
            id: UUID(),
            name: "Living Room",
            type: .room
        )
        
        do {
            try addLocation(livingRoom)
            
            // Main Bookshelf for manga and comics
            let mangaShelf = StorageLocation(
                id: UUID(),
                name: "Manga Shelf",
                type: .bookshelf,
                parentId: livingRoom.id
            )
            try addLocation(mangaShelf)
            
            // Comics shelf
            let comicsShelf = StorageLocation(
                id: UUID(),
                name: "Comics Shelf",
                type: .bookshelf,
                parentId: livingRoom.id
            )
            try addLocation(comicsShelf)
            
            // Gaming cabinet
            let gameCabinet = StorageLocation(
                id: UUID(),
                name: "Game Cabinet",
                type: .cabinet,
                parentId: livingRoom.id
            )
            try addLocation(gameCabinet)
            
            // Storage boxes
            let onePieceBox = StorageLocation(
                id: UUID(),
                name: "One Piece Collection Box",
                type: .box,
                parentId: mangaShelf.id
            )
            try addLocation(onePieceBox)
            
            let marvelBox = StorageLocation(
                id: UUID(),
                name: "Marvel Comics Box",
                type: .box,
                parentId: comicsShelf.id
            )
            try addLocation(marvelBox)
            
            let dcBox = StorageLocation(
                id: UUID(),
                name: "DC Comics Box",
                type: .box,
                parentId: comicsShelf.id
            )
            try addLocation(dcBox)
            
            let nintendoBox = StorageLocation(
                id: UUID(),
                name: "Nintendo Games Box",
                type: .box,
                parentId: gameCabinet.id
            )
            try addLocation(nintendoBox)
            
            let playstationBox = StorageLocation(
                id: UUID(),
                name: "PlayStation Games Box",
                type: .box,
                parentId: gameCabinet.id
            )
            try addLocation(playstationBox)
            
            // Literature shelf
            let literatureShelf = StorageLocation(
                id: UUID(),
                name: "Literature Shelf",
                type: .bookshelf,
                parentId: livingRoom.id
            )
            try addLocation(literatureShelf)
            
            let fictionBox = StorageLocation(
                id: UUID(),
                name: "Fiction Books Box",
                type: .box,
                parentId: literatureShelf.id
            )
            try addLocation(fictionBox)
            
            let nonFictionBox = StorageLocation(
                id: UUID(),
                name: "Non-Fiction Books Box",
                type: .box,
                parentId: literatureShelf.id
            )
            try addLocation(nonFictionBox)
            
        } catch {
            print("Error loading sample data: \(error.localizedDescription)")
        }
    }
    
    // Add validation method for inventory items
    func validateLocationId(_ locationId: UUID?) -> Bool {
        guard let id = locationId else { return true }
        return locations.keys.contains(id)
    }
    
    // Check for circular references
    private func wouldCreateCircularReference(_ location: StorageLocation, newParentId: UUID) -> Bool {
        var currentId = newParentId
        while let current = locations[currentId] {
            if current.id == location.id {
                return true
            }
            guard let parentId = current.parentId else {
                break
            }
            currentId = parentId
        }
        return false
    }
    
    // Validate location update
    private func validateLocationUpdate(_ location: StorageLocation) throws {
        // Check if location exists
        guard locations[location.id] != nil else {
            throw LocationError.locationNotFound
        }
        
        // Check for circular reference if parent is changing
        if let newParentId = location.parentId,
           let oldLocation = locations[location.id],
           oldLocation.parentId != newParentId {
            if wouldCreateCircularReference(location, newParentId: newParentId) {
                throw LocationError.circularReference
            }
        }
        
        // Validate parent-child relationship
        if let parentId = location.parentId {
            guard let parent = locations[parentId] else {
                throw LocationError.parentNotFound
            }
            
            guard parent.canAdd(childType: location.type) else {
                throw LocationError.invalidChildType
            }
        }
    }
    
    // MARK: - Hierarchy Management
    
    func removeLocationAndChildren(_ locationId: UUID) throws {
        guard let location = locations[locationId] else {
            throw LocationError.locationNotFound
        }
        
        // Check if any items exist in this location or its children
        if hasItemsInLocationOrChildren(locationId) {
            throw LocationError.invalidOperation("Cannot delete location that contains items")
        }
        
        // Remove all descendants recursively
        let descendants = descendants(of: locationId)
        for descendant in descendants {
            locations.removeValue(forKey: descendant.id)
        }
        
        // Remove from parent
        if let parentId = location.parentId {
            var parent = locations[parentId]
            parent?.removeChild(locationId)
            if let updatedParent = parent {
                locations[parentId] = updatedParent
            }
        }
        
        // Remove the location itself
        locations.removeValue(forKey: locationId)
        
        // Notify inventory view model
        inventoryViewModel?.handleLocationRemoval(locationId)
    }
    
    private func hasItemsInLocationOrChildren(_ locationId: UUID) -> Bool {
        // Check if location has items
        if inventoryViewModel?.hasItemsInLocation(locationId) == true {
            return true
        }
        
        // Check all descendants
        let descendantLocations = descendants(of: locationId)
        return descendantLocations.contains { location in
            inventoryViewModel?.hasItemsInLocation(location.id) == true
        }
    }
    
    func moveLocation(_ locationId: UUID, to newParentId: UUID?) throws {
        guard var location = locations[locationId] else {
            throw LocationError.locationNotFound
        }
        
        // If moving to root level
        if newParentId == nil {
            guard location.type == .room else {
                throw LocationError.invalidOperation("Only rooms can be root locations")
            }
            
            // Remove from old parent if exists
            if let oldParentId = location.parentId {
                var oldParent = locations[oldParentId]
                oldParent?.removeChild(locationId)
                if let updatedOldParent = oldParent {
                    locations[oldParentId] = updatedOldParent
                }
            }
            
            location.parentId = nil
            locations[locationId] = location
            return
        }
        
        // Moving to new parent
        guard let newParent = locations[newParentId!] else {
            throw LocationError.parentNotFound
        }
        
        // Check for circular reference
        if wouldCreateCircularReference(location, newParentId: newParentId!) {
            throw LocationError.circularReference
        }
        
        // Validate parent can accept this type
        guard newParent.canAdd(childType: location.type) else {
            throw LocationError.invalidChildType
        }
        
        // Remove from old parent if exists
        if let oldParentId = location.parentId {
            var oldParent = locations[oldParentId]
            oldParent?.removeChild(locationId)
            if let updatedOldParent = oldParent {
                locations[oldParentId] = updatedOldParent
            }
        }
        
        // Add to new parent
        var updatedNewParent = newParent
        guard updatedNewParent.addChild(locationId) else {
            throw LocationError.addChildFailed
        }
        
        location.parentId = newParentId
        
        // Save changes
        locations[locationId] = location
        locations[newParentId!] = updatedNewParent
    }
    
    func renameLocation(_ locationId: UUID, to newName: String) throws {
        guard var location = locations[locationId] else {
            throw LocationError.locationNotFound
        }
        
        guard !newName.isEmpty else {
            throw LocationError.invalidOperation("Location name cannot be empty")
        }
        
        location.name = newName
        locations[locationId] = location
        
        // Notify inventory view model of name change
        inventoryViewModel?.handleLocationRename(locationId, newName: newName)
    }
    
    private func validateLocationAdd(_ location: StorageLocation) throws {
        // Check for duplicate ID
        guard !locations.keys.contains(location.id) else {
            throw LocationError.duplicateId
        }
        
        // Validate category placement
        switch location.type.category {
        case .room:
            // Rooms can only be at root level
            if location.parentId != nil {
                throw LocationError.invalidOperation("Rooms must be created at the root level")
            }
        case .furniture, .container:
            // Furniture and containers must be inside a room or appropriate parent
            guard let parentId = location.parentId,
                  let parent = locations[parentId] else {
                throw LocationError.invalidOperation("\(location.type.category.rawValue) must be placed inside a room or appropriate container")
            }
            
            guard parent.canAdd(childType: location.type) else {
                throw LocationError.invalidChildType
            }
        }
    }
    
    func breadcrumbPath(for locationId: UUID) -> String {
        let ancestors = ancestors(of: locationId).reversed()
        let locationName = location(withId: locationId)?.name ?? ""
        return (ancestors.map { $0.name } + [locationName]).joined(separator: " > ")
    }
}

// MARK: - Errors
enum LocationError: LocalizedError {
    case duplicateId
    case parentNotFound
    case invalidChildType
    case addChildFailed
    case locationNotFound
    case circularReference
    case invalidOperation(String)
    
    var errorDescription: String? {
        switch self {
        case .duplicateId:
            return "Location ID already exists"
        case .parentNotFound:
            return "Parent location not found"
        case .invalidChildType:
            return "Invalid child location type"
        case .addChildFailed:
            return "Failed to add child location"
        case .locationNotFound:
            return "Location not found"
        case .circularReference:
            return "Cannot create circular reference in location hierarchy"
        case .invalidOperation(let reason):
            return reason
        }
    }
} 