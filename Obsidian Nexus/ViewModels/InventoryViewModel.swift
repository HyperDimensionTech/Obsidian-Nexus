import Foundation

class InventoryViewModel: ObservableObject {
    @Published private(set) var items: [InventoryItem] = []
    @Published private(set) var trashedItems: [InventoryItem] = []
    @Published private(set) var trashCount: Int = 0
    @Published var continuousScanEnabled = false
    @Published var pendingItems: [InventoryItem] = []
    
    // Add persistence layer
    private let storage: StorageManager
    private let locationManager: LocationManager
    
    init(storage: StorageManager = .shared, locationManager: LocationManager) {
        self.storage = storage
        self.locationManager = locationManager
        
        // Load existing items
        do {
            items = try storage.loadItems()
        } catch {
            print("Error loading items: \(error.localizedDescription)")
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
    private func validateItem(_ item: InventoryItem, isUpdate: Bool = false) throws {
        // For updates, we need to exclude the current item from duplicate checks
        let otherItems = isUpdate ? items.filter({ $0.id != item.id }) : items
        
        // Check for duplicate ISBN
        if let isbn = item.isbn,
           otherItems.contains(where: { $0.isbn == isbn }) {
            throw ValidationError.duplicateISBN(isbn)
        }
        
        // For series items, check for duplicate volumes
        if let series = item.series,
           let volume = item.volume,
           otherItems.contains(where: { 
               $0.series == series && $0.volume == volume && $0.id != item.id
           }) {
            throw ValidationError.duplicateInSeries(series, volume)
        }
        
        // For non-series items, check for duplicate titles
        if item.series == nil,
           otherItems.contains(where: { 
               $0.title.lowercased() == item.title.lowercased() && $0.id != item.id
           }) {
            throw ValidationError.duplicateTitle(item.title)
        }
    }
    
    // Update addItem method
    @discardableResult
    func addItem(_ item: InventoryItem) throws -> InventoryItem {
        try validateItem(item)
        var newItem = item
        // Clean up series name before adding
        newItem.series = cleanupSeriesName(item.series)
        try storage.save(newItem)
        items = try storage.loadItems()
        return newItem
    }
    
    func deleteItem(_ item: InventoryItem) throws {
        do {
            try storage.deleteItem(item.id)
            // Remove the item from the published items array
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items.remove(at: index)
            }
        } catch {
            print("Error deleting item: \(error.localizedDescription)")
            throw error
        }
    }
    
    @discardableResult
    func updateItem(_ item: InventoryItem) throws -> InventoryItem {
        print("ViewModel updating item with image size: \(item.customImageData?.count ?? 0) bytes")  // Debug
        try validateItem(item, isUpdate: true)
        var updatedItem = item
        updatedItem.series = cleanupSeriesName(item.series)
        try storage.update(updatedItem)
        
        // Add debug print
        print("Updating item with image source: \(updatedItem.imageSource), has image data: \(updatedItem.customImageData != nil)")
        
        items = try storage.loadItems()
        return updatedItem
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
        
        let searchTerms = query.lowercased().split(separator: " ").map(String.init)
        
        return items.filter { item in
            // Check if all search terms match any of these fields
            searchTerms.allSatisfy { term in
                // Title match (including "the" handling)
                let normalizedTitle = item.title.lowercased()
                    .replacingOccurrences(of: "the ", with: "")
                    .replacingOccurrences(of: "a ", with: "")
                    .replacingOccurrences(of: "an ", with: "")
                
                // Author match (including partial name matches)
                let authorMatch = item.author?.lowercased().contains(term) ?? false
                
                // Series match
                let seriesMatch = item.series?.lowercased().contains(term) ?? false
                
                return normalizedTitle.contains(term) || authorMatch || seriesMatch
            }
        }
    }
    
    func mangaSeries() -> [(String, [InventoryItem])] {
        let mangaItems = items.filter { $0.type == .manga }
        let groupedItems = Dictionary(grouping: mangaItems) { 
            cleanupSeriesName($0.series ?? "") ?? ""  // Clean up here
        }
        return groupedItems.map { series, items in
            (
                cleanupSeriesName(series) ?? series,  // And here
                items.sorted { 
                    if let vol1 = $0.volume, let vol2 = $1.volume {
                        return vol1 < vol2
                    }
                    return $0.title < $1.title
                }
            )
        }
        .sorted { $0.0 < $1.0 }
    }
    
    // MARK: - Sample Data
    
    func loadSampleData() {
        // Sample manga items
        let onepiece = InventoryItem(
            title: "One Piece",
            type: .manga,
            series: "One Piece",
            volume: 1,
            condition: .good,
            locationId: nil,
            notes: "First volume of the series",
            id: UUID(),
            dateAdded: Date(),
            barcode: nil,
            thumbnailURL: nil,
            author: "Eiichiro Oda",
            manufacturer: nil,
            originalPublishDate: nil,
            publisher: "Viz Media",
            isbn: "9781569319017",
            price: Decimal(14.99),
            purchaseDate: nil,
            synopsis: nil
        )
        
        let naruto = InventoryItem(
            title: "Naruto",
            type: .manga,
            series: "Naruto",
            volume: 1,
            condition: .good,
            locationId: nil,
            notes: "Classic ninja series",
            id: UUID(),
            dateAdded: Date(),
            barcode: nil,
            thumbnailURL: nil,
            author: "Masashi Kishimoto",
            manufacturer: nil,
            originalPublishDate: nil,
            publisher: "Viz Media",
            isbn: "9781569319000",
            price: Decimal(9.99),
            purchaseDate: nil,
            synopsis: nil
        )
        
        // Sample comic items
        let spiderman = InventoryItem(
            title: "The Amazing Spider-Man",
            type: .comics,
            series: "The Amazing Spider-Man",
            volume: 1,
            condition: .fair,
            locationId: nil,
            notes: "First appearance of Spider-Man",
            id: UUID(),
            dateAdded: Date(),
            barcode: nil,
            thumbnailURL: nil,
            author: "Stan Lee",
            manufacturer: nil,
            originalPublishDate: nil,
            publisher: "Marvel Comics",
            price: Decimal(29.99),
            purchaseDate: nil,
            synopsis: nil
        )
        
        // Sample video game
        let finalFantasy = InventoryItem(
            title: "Final Fantasy VII",
            type: .games,
            series: nil,
            volume: nil,
            condition: .good,
            locationId: nil,
            notes: "Classic PlayStation RPG",
            id: UUID(),
            dateAdded: Date(),
            barcode: nil,
            thumbnailURL: nil,
            author: nil,
            manufacturer: "Square Enix",
            originalPublishDate: Calendar.current.date(from: DateComponents(year: 1997)),
            publisher: nil,
            isbn: nil,
            price: Decimal(59.99),
            purchaseDate: nil,
            synopsis: nil
        )
        
        // Sample book
        let dune = InventoryItem(
            title: "Dune",
            type: .books,
            series: nil,
            volume: nil,
            condition: .good,
            locationId: nil,
            notes: "Science fiction masterpiece",
            id: UUID(),
            dateAdded: Date(),
            barcode: nil,
            thumbnailURL: nil,
            author: "Frank Herbert",
            manufacturer: nil,
            originalPublishDate: nil,
            publisher: "Ace Books",
            isbn: "9780441172719",
            price: Decimal(18.99),
            purchaseDate: nil,
            synopsis: "Set on the desert planet Arrakis, Dune is the story of the boy Paul Atreides, heir to a noble family tasked with ruling an inhospitable world where the only thing of value is the spice melange."
        )
        
        let sampleItems = [onepiece, naruto, spiderman, finalFantasy, dune]
        
        do {
            for item in sampleItems {
                try storage.save(item)
            }
            // Refresh items from storage
            items = try storage.loadItems()
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
            .sorted { 
                // Sort by volume number if both have volumes
                if let vol1 = $0.volume, let vol2 = $1.volume {
                    return vol1 < vol2
                }
                // Handle cases where volume numbers might be missing
                return $0.title < $1.title
            }
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
                var updatedItem = items[index]
                updatedItem.locationId = locationId
                try validateItem(updatedItem, isUpdate: true)  // Add isUpdate flag
                items[index] = updatedItem
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
    
    // Add method to load items that respects soft deletes
    func reloadItems() {
        do {
            items = try storage.loadItems()
        } catch {
            print("Error reloading items: \(error.localizedDescription)")
        }
    }
    
    func loadTrashedItems() {
        do {
            trashedItems = try storage.loadTrashedItems()
            trashCount = trashedItems.count
        } catch {
            print("Error loading trashed items: \(error.localizedDescription)")
        }
    }
    
    func restoreItem(_ item: InventoryItem) throws {
        try storage.restoreItem(item.id)
        if let index = trashedItems.firstIndex(where: { $0.id == item.id }) {
            trashedItems.remove(at: index)
        }
        reloadItems()
        trashCount -= 1
    }
    
    func emptyTrash() throws {
        try storage.emptyTrash()
        trashedItems.removeAll()
        trashCount = 0
    }
    
    func handleLocationMove(_ locationId: UUID, newParentId: UUID) {
        // No need to update items as they reference the location ID directly
        // and that ID hasn't changed
        objectWillChange.send()
    }
    
    func updateItemLocation(_ item: InventoryItem, to locationId: UUID?) {
        print("Updating item \(item.id) location to \(String(describing: locationId))")
        
        var updatedItem = item
        updatedItem.locationId = locationId
        
        do {
            try storage.update(updatedItem)
            
            // Verify the update
            if let repo = storage.itemRepository as? SQLiteItemRepository {
                repo.verifyItemLocation(item.id)
            }
            
            // Update in-memory state
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index] = updatedItem
            }
            
            print("Successfully updated item location")
        } catch {
            print("Failed to update item location: \(error.localizedDescription)")
        }
    }
    
    func bulkUpdateItems(items: [InventoryItem], updates: InventoryItem, fields: Set<String>) throws {
        guard !items.isEmpty else {
            throw BulkUpdateError.noItemsSelected
        }
        
        try storage.beginTransaction()
        
        do {
            for var item in items {
                if fields.contains("type") {
                    item.type = updates.type
                }
                if fields.contains("location") {
                    item.locationId = updates.locationId
                }
                if fields.contains("condition") {
                    item.condition = updates.condition
                }
                if fields.contains("price") {
                    item.price = updates.price
                }
                if fields.contains("purchaseDate") {
                    item.purchaseDate = updates.purchaseDate
                }
                
                try updateItem(item)
            }
            
            try storage.commitTransaction()
            
        } catch {
            try storage.rollbackTransaction()
            throw BulkUpdateError.transactionFailed(error.localizedDescription)
        }
    }
    
    enum BulkUpdateError: LocalizedError {
        case noItemsSelected
        case invalidLocation
        case transactionFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .noItemsSelected:
                return "No items selected for update"
            case .invalidLocation:
                return "Selected location is invalid"
            case .transactionFailed(let message):
                return "Failed to update items: \(message)"
            }
        }
    }
    
    // Add these methods
    func booksByAuthor() -> [(String, [InventoryItem])] {
        let bookItems = items.filter { $0.type == .books }
        let groupedItems = Dictionary(grouping: bookItems) { $0.author ?? "Unknown Author" }
        return groupedItems.map { ($0.key, $0.value) }
            .sorted { $0.0 < $1.0 }
    }
    
    func itemCount(for author: String) -> Int {
        items.filter { $0.type == .books && $0.author == author }.count
    }
    
    // Add to existing ValidationError enum or create new BulkOperationError
    enum BulkOperationError: LocalizedError {
        case noItemsSelected
        case transactionFailed(String)
        case deletionFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .noItemsSelected:
                return "No items selected for deletion"
            case .transactionFailed(let message):
                return "Failed to complete operation: \(message)"
            case .deletionFailed(let message):
                return "Failed to delete items: \(message)"
            }
        }
    }
    
    // Add bulk delete method
    func bulkDeleteItems(with ids: Set<UUID>) throws {
        guard !ids.isEmpty else {
            throw BulkOperationError.noItemsSelected
        }
        
        do {
            // Begin transaction
            try storage.beginTransaction()
            
            // Delete each item
            for id in ids {
                try storage.deleteItem(id)
            }
            
            // Commit transaction
            try storage.commitTransaction()
            
            // Update the published items array
            items = items.filter { !ids.contains($0.id) }
            
        } catch {
            // Rollback on error
            try? storage.rollbackTransaction()
            throw BulkOperationError.deletionFailed(error.localizedDescription)
        }
    }
    
    func updateItemType(_ item: InventoryItem, newType: CollectionType) throws {
        // Validate type change
        if item.type != newType {
            var updatedItem = item
            updatedItem.type = newType
            try validateItem(updatedItem, isUpdate: true)
            
            // Update item
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index] = updatedItem
                try storage.save(items)
            }
        }
    }
    
    func bulkUpdateType(items: [InventoryItem], newType: CollectionType) throws {
        try storage.beginTransaction()
        
        for var item in items {
            item.type = newType
            try validateItem(item, isUpdate: true)
        }
        
        try storage.commitTransaction()
        try storage.save(self.items)
    }
    
    func authorStats(name: String) -> (value: Decimal, count: Int) {
        let authorBooks = items.filter { $0.creator == name }
        let totalValue = authorBooks.compactMap { $0.price }.reduce(0, +)
        return (value: totalValue, count: authorBooks.count)
    }
    
    func itemsByAuthor(_ author: String) -> [InventoryItem] {
        items.filter { $0.creator == author }
            .sorted { $0.title < $1.title }
    }
    
    private func cleanupSeriesName(_ name: String?) -> String? {
        guard let name = name, !name.isEmpty else { return nil }
        var cleaned = name
            .trimmingCharacters(in: .punctuationCharacters)
            .trimmingCharacters(in: .whitespaces)
        
        // Remove trailing commas and spaces if they exist
        while cleaned.hasSuffix(",") || cleaned.hasSuffix(" ") {
            cleaned = String(cleaned.dropLast())
        }
        
        return cleaned.isEmpty ? nil : cleaned
    }
    
    func addBatchItems(_ items: [InventoryItem]) throws {
        try storage.saveBatch(items)
        items.forEach { item in
            if !self.items.contains(where: { $0.id == item.id }) {
                self.items.append(item)
            }
        }
    }
    
    func createItemFromGoogleBook(_ book: GoogleBook) -> InventoryItem {
        print("===== Processing Book =====")
        print("Title: \(book.volumeInfo.title)")
        print("Publisher: \(book.volumeInfo.publisher ?? "nil")")
        print("Type before: \(detectItemType(book))")
        
        let (series, volume) = extractSeriesInfo(from: book.volumeInfo.title)
        print("Series extraction result - series: \(series ?? "nil"), volume: \(volume ?? -1)")
        
        let type = detectItemType(book)
        print("Final type: \(type)")
        
        let item = InventoryItem(
            title: book.volumeInfo.title,
            type: type,
            series: series,
            volume: volume,
            condition: .good,
            barcode: book.volumeInfo.industryIdentifiers?.first?.identifier,
            thumbnailURL: book.volumeInfo.imageLinks?.thumbnail.flatMap { urlString -> URL? in
                var secureUrlString = urlString
                if urlString.hasPrefix("http://") {
                    secureUrlString = "https://" + urlString.dropFirst(7)
                }
                return URL(string: secureUrlString)
            },
            author: book.volumeInfo.authors?.first,
            originalPublishDate: parseDate(book.volumeInfo.publishedDate),
            publisher: book.volumeInfo.publisher,
            isbn: book.volumeInfo.industryIdentifiers?.first?.identifier,
            synopsis: book.volumeInfo.description,
            imageSource: .googleBooks
        )
        print("Created item - title: \(item.title), type: \(item.type), series: \(item.series ?? "nil"), volume: \(item.volume ?? -1)")
        print("========================")
        return item
    }
    
    private func detectItemType(_ book: GoogleBook) -> CollectionType {
        // Try database classification first
        let databaseType = storage.classifyItem(
            title: book.volumeInfo.title,
            publisher: book.volumeInfo.publisher,
            description: book.volumeInfo.description
        )
        
        // If database classification returns books (default), try fallback method
        if databaseType == .books {
            // Fallback to hardcoded rules
            let publisher = book.volumeInfo.publisher?.lowercased() ?? ""
            if publisher.contains("viz") || publisher.contains("kodansha") || 
               publisher.contains("seven seas") || publisher.contains("yen press") {
                return .manga
            }
            
            let title = book.volumeInfo.title.lowercased()
            let description = book.volumeInfo.description?.lowercased() ?? ""
            
            if title.contains("manga") || description.contains("manga") ||
               title.contains("vol.") || title.contains("volume") {
                return .manga
            } else if title.contains("comic") || description.contains("comic") {
                return .comics
            }
        }
        
        return databaseType
    }
    
    private func extractSeriesInfo(from title: String) -> (String?, Int?) {
        print("🔍 Attempting to extract series info from: \(title)")
        
        // Common manga volume patterns
        let patterns = [
            // Full series name with colon (keep everything before subtitle)
            "^(.*?):.*$",
            // Standard volume patterns
            "^(.*?),?\\s*(?:Vol\\.?|Volume)\\s*(\\d+)",
            "^(.*?)\\s+(\\d+)$",
            "^(.*?),?\\s*(?:Vol\\.?|Volume)\\s*(\\d+):",
            "^(.*?)\\s+(?:Vol\\.?|Volume)\\s*(\\d+)",
            // Handle "Series Name - Subtitle" pattern
            "^([^-]+)\\s*-.*$"
        ]
        
        for (index, pattern) in patterns.enumerated() {
            print("Trying pattern \(index): \(pattern)")
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: title, options: [], range: NSRange(title.startIndex..., in: title)) {
                
                print("✅ Matched pattern index: \(index)")
                
                let seriesRange = match.range(at: 1)
                let volumeRange = match.numberOfRanges > 2 ? match.range(at: 2) : NSRange(location: 0, length: 0)
                
                if let seriesRange = Range(seriesRange, in: title) {
                    // Get the full series name for titles with colons
                    let series = if index == 0 {
                        // For colon pattern, keep the full title as series
                        title
                    } else {
                        String(title[seriesRange])
                            .trimmingCharacters(in: .whitespaces)
                            .trimmingCharacters(in: .punctuationCharacters)
                    }
                    
                    if volumeRange.location == 0 {
                        print("📚 Extracted series (no volume): \(series)")
                        return (series, nil)
                    }
                    
                    if let volumeRange = Range(volumeRange, in: title),
                       let volume = Int(title[volumeRange]) {
                        print("📚 Extracted series: \(series), volume: \(volume)")
                        return (series, volume)
                    }
                    
                    print("📚 Returning series without volume: \(series)")
                    return (series, nil)
                }
            }
        }
        
        print("❌ No pattern match found")
        return (nil, nil)
    }
    
    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }
} 