import Foundation

class InventoryViewModel: ObservableObject {
    @Published private(set) var items: [InventoryItem] = []
    
    // Add persistence layer
    private let storage: StorageManager
    private let locationManager: LocationManager
    
    init(storage: StorageManager = StorageManager.shared,
         locationManager: LocationManager) {
        self.storage = storage
        self.locationManager = locationManager
        do {
            items = try storage.load()
        } catch {
            print("Failed to load items: \(error.localizedDescription)")
            loadSampleData()
        }
    }
    
    func saveItems() {
        try? storage.save(items)
    }
    
    // MARK: - Item Management
    
    // Add validation errors
    enum ValidationError: LocalizedError {
        case duplicateISBN(String)
        case duplicateTitle(String)
        case duplicateInSeries(String, Int)
        
        var errorDescription: String? {
            switch self {
            case .duplicateISBN(let isbn):
                return "An item with ISBN \(isbn) already exists in your collection"
            case .duplicateTitle(let title):
                return "An item titled '\(title)' already exists in your collection"
            case .duplicateInSeries(let series, let volume):
                return "Volume \(volume) of '\(series)' already exists in your collection"
            }
        }
    }
    
    // Add validation method
    private func validateItem(_ item: InventoryItem, isEditing: Bool = false) throws {
        // When editing, we need to exclude the current item from duplicate checks
        let otherItems = isEditing ? items.filter({ $0.id != item.id }) : items
        
        // Check for duplicate ISBN if it exists
        if let isbn = item.isbn,
           otherItems.contains(where: { $0.isbn == isbn }) {
            throw ValidationError.duplicateISBN(isbn)
        }
        
        // For series items, check for duplicate volumes
        if let series = item.series,
           let volume = item.volume,
           otherItems.contains(where: { 
               $0.series == series && $0.volume == volume 
           }) {
            throw ValidationError.duplicateInSeries(series, volume)
        }
        
        // For non-series items, check for duplicate titles
        if item.series == nil,
           otherItems.contains(where: { 
               $0.title.lowercased() == item.title.lowercased() 
           }) {
            throw ValidationError.duplicateTitle(item.title)
        }
    }
    
    // Update addItem method
    func addItem(_ item: InventoryItem) throws {
        // Validate before adding
        try validateItem(item)
        
        // Create new item with a guaranteed UUID
        let newItem = InventoryItem(
            title: item.title,
            type: item.type,
            series: item.series,
            volume: item.volume,
            condition: item.condition,
            locationId: item.locationId,
            notes: item.notes,
            id: item.id == UUID() ? UUID() : item.id,  // Generate new ID only if default
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
            synopsis: item.synopsis
        )
        
        items.append(newItem)
        saveItems()
        
        objectWillChange.send()
    }
    
    func deleteItem(_ item: InventoryItem) {
        items.removeAll { $0.id == item.id }
        saveItems()
    }
    
    func updateItem(_ item: InventoryItem) throws {
        // Validate the item with isEditing flag
        try validateItem(item, isEditing: true)
        
        // Find and update the item
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
            saveItems()
        } else {
            throw InventoryError.invalidOperation("Item not found")
        }
    }
    
    // MARK: - Item Queries
    
    var recentItems: [InventoryItem] {
        Array(items.sorted { $0.dateAdded > $1.dateAdded }.prefix(5))
    }
    
    var totalItems: Int {
        items.count
    }
    
    func items(for type: CollectionType) -> [InventoryItem] {
        items.filter { $0.type == type }
    }
    
    func itemCount(for type: CollectionType) -> Int {
        items(for: type).count
    }
    
    func searchItems(query: String) -> [InventoryItem] {
        guard !query.isEmpty else { return items }
        
        let lowercasedQuery = query.lowercased()
        return items.filter { item in
            item.title.lowercased().contains(lowercasedQuery) ||
            (item.series?.lowercased().contains(lowercasedQuery) ?? false)
        }
    }
    
    func mangaSeries() -> [(String, [InventoryItem])] {
        let mangaItems = items.filter { $0.type == .manga }
        let groupedItems = Dictionary(grouping: mangaItems) { $0.series ?? "" }
        return groupedItems.map { ($0.key, $0.value) }
            .sorted { $0.0 < $1.0 }
    }
    
    // MARK: - Sample Data
    
    func loadSampleData() {
        let livingRoom = StorageLocation(
            id: UUID(),
            name: "Living Room",
            type: .room
        )
        
        do {
            try locationManager.addLocation(livingRoom)
            
            items = [
                // Manga Series - One Piece Volumes
                InventoryItem(
                    title: "One Piece Vol. 1",
                    type: .manga,
                    series: "One Piece",
                    volume: 1,
                    condition: .new,
                    locationId: livingRoom.id,
                    notes: "Romance Dawn",
                    author: "Eiichiro Oda",
                    originalPublishDate: Calendar.current.date(from: DateComponents(year: 1997, month: 7, day: 22)),
                    publisher: "Shueisha",
                    isbn: "978-4088725093",
                    price: 9.99,
                    purchaseDate: Calendar.current.date(from: DateComponents(year: 2023, month: 11, day: 1)),
                    synopsis: "The story follows Monkey D. Luffy, a young man who sets off on a journey from the East Blue Sea to find the titular treasure and proclaim himself the King of the Pirates."
                ),
                
                // Books
                InventoryItem(
                    title: "The Lord of the Rings",
                    type: .books,
                    series: "The Lord of the Rings",
                    condition: .good,
                    locationId: livingRoom.id,
                    notes: "First edition hardcover",
                    author: "J.R.R. Tolkien",
                    originalPublishDate: Calendar.current.date(from: DateComponents(year: 1954, month: 7, day: 29)),
                    publisher: "Allen & Unwin",
                    isbn: "978-0261103252",
                    price: 149.99,
                    purchaseDate: Calendar.current.date(from: DateComponents(year: 2023, month: 12, day: 15)),
                    synopsis: "The Lord of the Rings tells of the great quest undertaken by Frodo Baggins and the Fellowship of the Ring."
                ),
                
                // Games
                InventoryItem(
                    title: "PlayStation 5",
                    type: .games,
                    condition: .likeNew,
                    locationId: livingRoom.id,
                    notes: "Digital Edition",
                    manufacturer: "Sony",
                    originalPublishDate: Calendar.current.date(from: DateComponents(year: 2020, month: 11, day: 12)),
                    price: 499.99,
                    purchaseDate: Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 5)),
                    synopsis: "Next-generation gaming console featuring ultra-high speed SSD, ray tracing support, and 4K gaming capabilities."
                )
                // ... continue with other items using locationId instead of location
            ]
        } catch {
            print("Error loading sample data: \(error.localizedDescription)")
        }
    }
    
    // Check if a location contains any items
    func hasItemsInLocation(_ locationId: UUID) -> Bool {
        items.contains { $0.locationId == locationId }
    }
    
    // Handle orphaned items when a location is deleted
    func handleLocationRemoval(_ locationId: UUID) {
        for index in items.indices {
            if items[index].locationId == locationId {
                items[index].locationId = nil
            }
        }
        saveItems()
    }
    
    // Handle location renames (if needed for UI updates)
    func handleLocationRename(_ locationId: UUID, newName: String) {
        // Optionally update any cached location names in items
        // This might not be necessary if you always fetch location names through LocationManager
    }
    
    // Helper methods for collections
    func itemsInSeries(_ series: String) -> [InventoryItem] {
        items.filter { $0.series == series }
    }
    
    func duplicateExists(_ item: InventoryItem) -> Bool {
        do {
            try validateItem(item)
            return false
        } catch {
            return true
        }
    }
    
    // Add this method
    func updateItemLocations(items itemIds: Set<UUID>, to locationId: UUID) throws {
        // Validate location
        guard locationManager.validateLocationId(locationId) else {
            throw InventoryError.invalidLocation
        }
        
        // Update each item
        for itemId in itemIds {
            if let index = items.firstIndex(where: { $0.id == itemId }) {
                items[index].locationId = locationId
            }
        }
        
        // Save changes
        saveItems()
    }
    
    // Collection value calculations
    func totalValue(for type: CollectionType? = nil) -> Decimal {
        let filteredItems = type == nil ? items : items.filter { $0.type == type }
        return filteredItems.reduce(0) { $0 + ($1.price ?? 0) }
    }
    
    func seriesValue(series: String) -> Decimal {
        items.filter { $0.series == series }
            .reduce(0) { $0 + ($1.price ?? 0) }
    }
    
    // Total value of all items
    var totalCollectionValue: Decimal {
        items.reduce(0) { $0 + ($1.price ?? 0) }
    }
    
    // Value by collection type
    func collectionValue(for type: CollectionType) -> Decimal {
        items.filter { $0.type == type }
            .reduce(0) { $0 + ($1.price ?? 0) }
    }
    
    // Value and completion for a specific series
    func seriesStats(name: String) -> (value: Decimal, count: Int, total: Int?) {
        let seriesItems = items.filter { $0.series == name }
        let value = seriesItems.reduce(0) { $0 + ($1.price ?? 0) }
        let count = seriesItems.count
        
        // Try to determine total volumes if available
        let total: Int? = nil // This could be enhanced with a series database
        
        return (value, count, total)
    }
    
    // Collection statistics
    var collectionStats: [(type: CollectionType, count: Int, value: Decimal)] {
        CollectionType.allCases.map { type in
            let typeItems = items.filter { $0.type == type }
            let count = typeItems.count
            let value = typeItems.reduce(0) { $0 + ($1.price ?? 0) }
            return (type, count, value)
        }
    }
} 