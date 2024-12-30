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
    
    func addItem(_ item: InventoryItem) throws {
        // Validate item before adding
        guard !item.title.isEmpty else {
            throw InventoryError.invalidTitle
        }
        items.append(item)
        saveItems()
    }
    
    func deleteItem(_ item: InventoryItem) {
        items.removeAll { $0.id == item.id }
        saveItems()
    }
    
    func updateItem(_ item: InventoryItem) throws {
        // Validate the item
        try validateItem(item)
        
        // Find and update the item
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
            saveItems()
        } else {
            throw InventoryError.invalidOperation("Item not found")
        }
    }
    
    private func validateItem(_ item: InventoryItem) throws {
        // Basic validation
        guard !item.title.isEmpty else {
            throw InventoryError.invalidTitle
        }
        
        // Location validation
        if let locationId = item.locationId {
            guard locationManager.validateLocationId(locationId) else {
                throw InventoryError.invalidLocation
            }
        }
        
        // Add any other validation rules here
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
} 