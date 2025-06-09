import Foundation

/**
 Manages the storage locations hierarchy and relationships.
 
 LocationManager is responsible for:
 - Loading and persisting location data
 - Maintaining the hierarchical structure of locations
 - Providing methods to query the location hierarchy
 - Ensuring data integrity when modifying locations
 
 It serves as the source of truth for all location-related operations and
 maintains parent-child relationships between locations.
 
 ## Usage
 
 ```swift
 // Access the location manager in a view
 struct LocationListView: View {
     @EnvironmentObject var locationManager: LocationManager
     
     var body: some View {
         List {
             ForEach(locationManager.rootLocations()) { location in
                 LocationRow(location: location)
             }
         }
     }
 }
 
 // Add a new location
 let newShelf = StorageLocation(
     name: "Living Room Bookshelf",
     type: .bookshelf,
     parentId: livingRoomId
 )
 try locationManager.addLocation(newShelf)
 ```
 
 ## Location Hierarchy Rules
 
 The location hierarchy follows these rules:
 - Rooms can only contain bookshelves, cabinets, or boxes
 - Bookshelves can only contain boxes
 - Cabinets can only contain boxes
 - Boxes cannot contain other locations
 - Circular references (a location containing one of its ancestors) are not allowed
 */
@MainActor
class LocationManager: ObservableObject {
    /// Dictionary of all locations, keyed by their UUID
    @Published private(set) var locations: [UUID: StorageLocation] = [:]
    
    /// Reference to the inventory view model for coordination
    private weak var inventoryViewModel: InventoryViewModel?
    
    /// Storage manager for persistence
    internal let storage: StorageManager
    
    /**
     Initializes the location manager.
     
     - Parameters:
        - storage: The storage manager to use for persistence
        - inventoryViewModel: Optional reference to the inventory view model for coordination
     */
    init(storage: StorageManager = .shared, inventoryViewModel: InventoryViewModel? = nil) {
        self.storage = storage
        self.inventoryViewModel = inventoryViewModel
        loadLocations()
    }
    
    /**
     Loads all locations from persistent storage and builds the hierarchy.
     
     This method:
     1. Loads locations from storage
     2. Builds a dictionary of locations by ID
     3. Establishes parent-child relationships
     */
    private func loadLocations() {
        do {
            // Verify database state first
            if let repo = storage.locationRepository as? SQLiteLocationRepository {
                repo.verifyDatabaseState()
            }
            
            // Load and process locations
            let loadedLocations = try storage.loadLocations()
            var locationDict: [UUID: StorageLocation] = [:]
            
            // First pass: create all locations
            for location in loadedLocations {
                locationDict[location.id] = location
            }
            
            // Second pass: build parent-child relationships
            for location in loadedLocations where location.parentId != nil {
                if var parent = locationDict[location.parentId!] {
                    if parent.addChild(location.id) {
                        locationDict[parent.id] = parent
                    } else {
                        print("Warning: Failed to add child \(location.id) to parent \(location.parentId!)")
                    }
                } else {
                    print("Warning: Parent \(location.parentId!) not found for location \(location.id)")
                }
            }
            
            self.locations = locationDict
            
        } catch DatabaseManager.DatabaseError.invalidData {
            print("Error: Invalid data in database")
            self.locations = [:]
        } catch {
            print("Error loading locations: \(error.localizedDescription)")
            self.locations = [:]
        }
    }
    
    /**
     Reloads all locations from persistent storage.
     
     Use this method when you need to refresh the location data,
     such as after a data import or when switching users.
     */
    func reloadLocations() {
        loadLocations()
    }
    
    // MARK: - Location Management
    
    /**
     Adds a new location to the hierarchy.
     
     This method validates the location, saves it to persistent storage,
     and updates the in-memory hierarchy.
     
     - Parameter location: The location to add
     - Throws: LocationError if the location cannot be added
     */
    func addLocation(_ location: StorageLocation) throws {
        try validateLocationAdd(location)
        
        // Save to database first
        try storage.save(location)
        
        // If database save succeeds, update in-memory state
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
    
    /**
     Adds a child location to a specific parent.
     
     This is a convenience method that sets the parent ID of the child
     and then adds it to the hierarchy.
     
     - Parameters:
        - child: The child location to add
        - parentId: The ID of the parent location
     - Throws: LocationError if the child cannot be added
     */
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
    
    /**
     Updates an existing location.
     
     This method validates the update, persists the changes,
     and updates the in-memory hierarchy.
     
     - Parameter location: The updated location
     - Throws: LocationError if the update is invalid or cannot be performed
     */
    func updateLocation(_ location: StorageLocation) throws {
        try validateLocationUpdate(location)
        
        let oldLocation = locations[location.id]
        
        // Save to database first
        try storage.update(location)
        
        // If database update succeeds, update in-memory state
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
    
    /**
     Removes a location from the hierarchy.
     
     This method validates that the location can be removed
     (has no items) and removes it from persistent storage
     and the in-memory hierarchy.
     
     - Parameter locationId: The ID of the location to remove
     - Throws: LocationError if the location cannot be removed
     */
    func removeLocation(_ locationId: UUID) throws {
        guard let location = locations[locationId] else {
            throw LocationError.locationNotFound
        }
        
        // Check if location has items
        if inventoryViewModel?.hasItemsInLocation(locationId) == true {
            throw LocationError.invalidOperation("Cannot delete location that contains items")
        }
        
        // Delete from database first
        try storage.deleteLocation(locationId)
        
        // If database delete succeeds, update in-memory state
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
    
    /**
     Returns the immediate children of a location.
     
     - Parameter locationId: The ID of the location
     - Returns: An array of child locations
     */
    func children(of locationId: UUID) -> [StorageLocation] {
        guard let parent = locations[locationId] else { return [] }
        return parent.childIds
            .compactMap { locations[$0] }
    }
    
    /**
     Returns the immediate children of a location, sorted by name.
     
     - Parameter locationId: The ID of the location
     - Returns: An array of child locations sorted by name
     */
    func childLocations(for locationId: UUID) -> [StorageLocation] {
        children(of: locationId)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    /**
     Returns all descendants of a location (children, grandchildren, etc.).
     
     - Parameter locationId: The ID of the location
     - Returns: An array of all descendant locations
     */
    func descendants(of locationId: UUID) -> [StorageLocation] {
        var result: [StorageLocation] = []
        let directChildren = children(of: locationId)
        result.append(contentsOf: directChildren)
        
        for child in directChildren {
            result.append(contentsOf: descendants(of: child.id))
        }
        
        return result
    }
    
    /**
     Returns all ancestors of a location (parent, grandparent, etc.).
     
     - Parameter locationId: The ID of the location
     - Returns: An array of all ancestor locations
     */
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
    
    /**
     Returns the full path to a location as a string.
     
     The path is formatted as "Parent > Child > Grandchild".
     
     - Parameter locationId: The ID of the location
     - Returns: A string representation of the path
     */
    func path(to locationId: UUID) -> String {
        let ancestors = ancestors(of: locationId).reversed()
        let locationName = locations[locationId]?.name ?? ""
        return (ancestors.map { $0.name } + [locationName]).joined(separator: " > ")
    }
    
    /**
     Returns a formatted string representation of a location and its descendants.
     
     This is useful for debugging and display purposes.
     
     - Parameters:
        - locationId: The ID of the location
        - indent: The indentation string to use (default: "")
     - Returns: A hierarchical string representation
     */
    func hierarchyString(for locationId: UUID, indent: String = "") -> String {
        guard let location = locations[locationId] else { return "" }
        
        var result = "\(indent)\(location.name) (\(location.type.rawValue))\n"
        for childId in location.childIds {
            result += hierarchyString(for: childId, indent: indent + "  ")
        }
        return result
    }
    
    // MARK: - Location Search
    
    /**
     Searches for locations matching the given query using fuzzy matching.
     
     This method searches location names with flexible matching that handles
     partial words, missing punctuation, and other common user input patterns.
     
     - Parameter query: The search query
     - Returns: An array of matching locations sorted by relevance
     */
    func searchLocations(query: String) -> [StorageLocation] {
        guard !query.isEmpty else { return [] }
        
        // Use fuzzy matching for more flexible search
        let matchingLocations = allLocations().filter { location in
            VolumeExtractor.fuzzyMatches(searchQuery: query, against: location.name)
        }
        
        // Sort by relevance: exact matches first, then prefix matches, then other fuzzy matches
        let normalizedQuery = query.lowercased()
        return matchingLocations.sorted { location1, location2 in
            let name1 = location1.name.lowercased()
            let name2 = location2.name.lowercased()
            
            // Exact matches come first
            if name1 == normalizedQuery && name2 != normalizedQuery {
                return true
            }
            if name2 == normalizedQuery && name1 != normalizedQuery {
                return false
            }
            
            // Prefix matches come second
            if name1.hasPrefix(normalizedQuery) && !name2.hasPrefix(normalizedQuery) {
                return true
            }
            if name2.hasPrefix(normalizedQuery) && !name1.hasPrefix(normalizedQuery) {
                return false
            }
            
            // Otherwise sort alphabetically
            return location1.name.localizedCaseInsensitiveCompare(location2.name) == .orderedAscending
        }
    }
    
    // MARK: - Utility Methods
    
    /**
     Returns the breadcrumb path for a location.
     
     This is similar to `path(to:)` but intended for UI display.
     
     - Parameter locationId: The ID of the location
     - Returns: A formatted breadcrumb path string
     */
    func breadcrumbPath(for locationId: UUID) -> String {
        let ancestors = ancestors(of: locationId).reversed()
        let locationName = location(withId: locationId)?.name ?? ""
        return (ancestors.map { $0.name } + [locationName]).joined(separator: " > ")
    }
    
    /**
     Returns a location by its ID.
     
     - Parameter id: The ID of the location
     - Returns: The location, or nil if not found
     */
    func location(withId id: UUID) -> StorageLocation? {
        locations[id]
    }
    
    /**
     Asynchronously loads a specific location from the database if not in memory.
     
     - Parameter id: The ID of the location to load
     */
    func loadLocation(withId id: UUID) async {
        // Check if we already have this location in memory
        if locations[id] != nil {
            return
        }
        
        do {
            // Load the location from database without capturing self
            if let location = try await storage.loadLocation(withId: id) {
                // Use MainActor to safely update the published property
                await MainActor.run {
                    // Update our in-memory state safely on the main thread
                    updateLocationsAfterLoad(location: location)
                }
            }
        } catch {
            print("Error loading location with ID \(id): \(error.localizedDescription)")
        }
    }
    
    /// Updates the locations dictionary after loading a location from the database
    /// This method must be called on the main thread
    @MainActor private func updateLocationsAfterLoad(location: StorageLocation) {
        // Add the location to our dictionary
        locations[location.id] = location
        
        // If this location has a parent, update the parent's child relationship
        if let parentId = location.parentId, var parent = locations[parentId] {
            if parent.addChild(location.id) {
                locations[parentId] = parent
            }
        }
    }
    
    /**
     Returns all locations in the hierarchy.
     
     - Returns: An array of all locations
     */
    func allLocations() -> [StorageLocation] {
        Array(locations.values)
    }
    
    /**
     Returns all locations of a specific type.
     
     - Parameter type: The location type to filter by
     - Returns: An array of locations of the specified type
     */
    func locations(ofType type: StorageLocation.LocationType) -> [StorageLocation] {
        allLocations().filter { $0.type == type }
    }
    
    /**
     Returns all top-level (root) locations.
     
     Root locations are those without a parent.
     
     - Returns: An array of root locations, sorted by name
     */
    func rootLocations() -> [StorageLocation] {
        allLocations()
            .filter { $0.parentId == nil }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    func loadSampleData() {
        // Check if we already have locations
        if !locations.isEmpty {
            return  // Don't load sample data if we already have locations
        }
        
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
        // Existing validation
        guard var location = locations[locationId] else {
            throw LocationError.locationNotFound
        }
        
        // Circular reference check
        if wouldCreateCircularReference(location, newParentId: newParentId!) {
            throw LocationError.circularReference
        }
        
        // Parent validation
        guard let newParent = locations[newParentId!] else {
            throw LocationError.parentNotFound
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
        print("Starting location rename process...")
        
        guard !newName.isEmpty else {
            print("Error: Empty name provided")
            throw LocationError.invalidOperation("Location name cannot be empty")
        }
        
        guard var location = locations[locationId] else {
            print("Error: Location \(locationId) not found in memory")
            throw LocationError.locationNotFound
        }
        
        print("Current location state: \(location)")
        
        do {
            // Update database first
            try storage.updateLocationName(locationId, newName: newName)
            print("Database update successful")
            
            // If database update succeeds, update in-memory state
            location.name = newName
            locations[locationId] = location
            print("In-memory state updated")
            
            // Notify inventory view model of the change
            inventoryViewModel?.handleLocationRename(locationId, newName: newName)
            print("ViewModel notified of change")
            
        } catch {
            print("Failed to rename location: \(error.localizedDescription)")
            throw LocationError.invalidOperation("Failed to rename location: \(error.localizedDescription)")
        }
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
    
    /// Moves a location and all its contents to a new parent location
    func migrateLocation(_ locationId: UUID, to newParentId: UUID) throws {
        // Validate locations exist
        guard var locationToMove = locations[locationId] else {
            throw LocationError.locationNotFound
        }
        
        guard let newParent = locations[newParentId] else {
            throw LocationError.parentNotFound
        }
        
        // Validate move is allowed
        guard locationToMove.type.category != .room else {
            throw LocationError.invalidOperation("Rooms cannot be moved to new parents")
        }
        
        // Check for circular reference
        if wouldCreateCircularReference(locationToMove, newParentId: newParentId) {
            throw LocationError.circularReference
        }
        
        // Validate new parent can accept this type
        guard newParent.canAdd(childType: locationToMove.type) else {
            throw LocationError.invalidOperation("\(newParent.name) cannot contain \(locationToMove.type.name)")
        }
        
        do {
            // Update database first
            try storage.updateLocationParent(locationId, newParentId: newParentId)
            
            // If database update succeeds, update in-memory state
            // Remove from old parent
            if let oldParentId = locationToMove.parentId {
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
            
            // Update location's parent
            locationToMove.parentId = newParentId
            
            // Save changes to in-memory state
            locations[locationId] = locationToMove
            locations[newParentId] = updatedNewParent
            
            // Notify inventory view model of the move
            inventoryViewModel?.handleLocationMove(locationId, newParentId: newParentId)
            
        } catch {
            throw LocationError.invalidOperation("Failed to update location: \(error.localizedDescription)")
        }
    }
    
    // Add a method to find a location by ID (from QR code)
    func getLocation(by id: UUID) -> StorageLocation? {
        return locations[id]
    }
    
    // Get all items in a location, including items in nested locations
    func getAllItemsInLocation(locationId: UUID, inventoryViewModel: InventoryViewModel) -> [InventoryItem] {
        var allItems: [InventoryItem] = []
        
        // Get direct items in this location
        let directItems = inventoryViewModel.items.filter { $0.locationId == locationId }
        allItems.append(contentsOf: directItems)
        
        // Get items from child locations recursively
        if let location = locations[locationId] {
            for childId in location.childIds {
                let childItems = getAllItemsInLocation(locationId: childId, inventoryViewModel: inventoryViewModel)
                allItems.append(contentsOf: childItems)
            }
        }
        
        return allItems
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