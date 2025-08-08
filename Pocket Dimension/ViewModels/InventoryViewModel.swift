import Foundation

@MainActor
class InventoryViewModel: ObservableObject {
    @Published private(set) var items: [InventoryItem] = []
    @Published private(set) var trashedItems: [InventoryItem] = []
    @Published private(set) var trashCount: Int = 0
    @Published var continuousScanEnabled = false
    @Published var pendingItems: [InventoryItem] = []
    
    // Dependencies
    private let storage: StorageManager
    private let locationManager: LocationManager
    private let services = ServiceContainer.shared
    private let duplicateDetectionService = DuplicateDetectionService()
    
    // Service shortcuts for cleaner code
    private var validationService: InventoryValidationService { services.inventoryValidationService }
    private var searchService: InventorySearchService { services.inventorySearchService }
    private var statsService: InventoryStatsService { services.inventoryStatsService }
    private var collectionService: CollectionManagementService { services.collectionManagementService }
    
    // Update the price-related properties
    @Published private(set) var totalValue: Price = Price(amount: 0)
    @Published private(set) var averagePrice: Price = Price(amount: 0)
    @Published private(set) var highestPrice: Price = Price(amount: 0)
    @Published private(set) var lowestPrice: Price = Price(amount: 0)
    @Published private(set) var medianPrice: Price = Price(amount: 0)
    
    init(storage: StorageManager = .shared, locationManager: LocationManager) {
        self.storage = storage
        self.locationManager = locationManager
        
        print("🟢 InventoryViewModel: Initializing and loading items from storage")
        
        // Debug: Show data counts from both repositories
        storage.debugDataCounts()
        
        // Load existing items
        do {
            items = try storage.loadItems()
            print("Successfully loaded \(items.count) items from storage")
            
            // Calculate statistics based on loaded items
            calculatePriceStats()
            
        } catch let error as DatabaseManager.DatabaseError {
            print("Database error loading items: \(error.localizedDescription)")
            items = []
        } catch {
            print("Error loading items: \(error.localizedDescription)")
            items = []
        }
    }
    
    deinit {
        print("🔴 InventoryViewModel: Deallocating")
    }
    
    func saveItems() {
        try? storage.save(items)
    }
    
    // MARK: - Item Management
    
    // Enhanced validation errors to include merge information
    enum ValidationError: LocalizedError {
        case duplicateISBN(String)
        case duplicateTitle(String)
        case duplicateInSeries(String, Int)
        case duplicateMerged(String, InventoryItem) // New case for merged duplicates
        
        var errorDescription: String? {
            switch self {
            case .duplicateISBN(let isbn):
                return "An item with ISBN \(isbn) already exists in your collection"
            case .duplicateTitle(let title):
                return "An item titled '\(title)' already exists in your collection"
            case .duplicateInSeries(let series, let volume):
                return "Volume \(volume) of '\(series)' already exists in your collection"
            case .duplicateMerged(let title, _):
                return "Item '\(title)' was already in your collection. Information has been merged."
            }
        }
        
        var isDuplicateMerged: Bool {
            if case .duplicateMerged = self {
                return true
            }
            return false
        }
        
        var mergedItem: InventoryItem? {
            if case .duplicateMerged(_, let item) = self {
                return item
            }
            return nil
        }
    }
    
    // Add validation method for compatibility with existing code
    private func validateItem(_ item: InventoryItem, isUpdate: Bool = false) throws {
        do {
            try validationService.validateForDuplicates(item, existingItems: items, isUpdate: isUpdate)
        } catch let error as InventoryValidationService.ValidationError {
            // Convert service validation errors to local validation errors for compatibility
            switch error {
            case .duplicateISBN(let isbn):
                throw ValidationError.duplicateISBN(isbn)
            case .duplicateInSeries(let series, let volume):
                throw ValidationError.duplicateInSeries(series, volume)
            case .duplicateTitle(let title):
                throw ValidationError.duplicateTitle(title)
            default:
                // For other validation errors, just rethrow
                throw error
            }
        }
    }
    
    // Enhanced addItem method with intelligent duplicate detection
    @discardableResult
    func addItem(_ item: InventoryItem) throws -> InventoryItem {
        print("Adding item: \(item.title)")
        
        // TEMPORARY: Disable advanced duplicate detection due to crashes
        // Use simple validation instead until string range issues are resolved
        try validateItem(item, isUpdate: false)
        
        /* DISABLED TEMPORARILY - CAUSES CRASHES
        // Use enhanced duplicate detection
        let duplicateResult = duplicateDetectionService.detectDuplicate(for: item, in: items)
        
        if duplicateResult.isDuplicate {
            guard let existingItem = duplicateResult.existingItem else {
                throw ValidationError.duplicateTitle(item.title)
            }
            
            print("Duplicate detected with confidence: \(duplicateResult.confidence), type: \(duplicateResult.matchType)")
            
            // Automatically merge items for high confidence matches
            if duplicateResult.confidence >= 0.85 {
                let mergedItem = duplicateDetectionService.mergeItems(existing: existingItem, new: item)
                
                do {
                    let updatedItem = try updateItem(mergedItem)
                    print("Successfully merged duplicate item: \(updatedItem.title)")
                    
                    // Throw special error to indicate successful merge
                    throw ValidationError.duplicateMerged(updatedItem.title, updatedItem)
                } catch let error as ValidationError {
                    // Re-throw validation errors (including duplicateMerged)
                    throw error
                } catch {
                    print("Error merging duplicate item: \(error.localizedDescription)")
                    // Fall back to original validation error
                    throw ValidationError.duplicateTitle(item.title)
                }
            } else {
                // Lower confidence - use traditional validation
                switch duplicateResult.matchType {
                case .exactISBN:
                    throw ValidationError.duplicateISBN(item.isbn ?? "")
                case .titleAuthorSeries:
                    if let series = item.series, let volume = item.volume {
                        throw ValidationError.duplicateInSeries(series, volume)
                    }
                    fallthrough
                default:
                    throw ValidationError.duplicateTitle(item.title)
                }
            }
        }
        */
        
        // No duplicate detected - proceed with normal add
        var newItem = item
        newItem.series = cleanupSeriesName(item.series)
        
        do {
            try storage.save(newItem)
            print("Successfully saved item to storage")
            
            do {
                items = try storage.loadItems()
                print("Reloaded \(items.count) items from storage")
            } catch {
                print("Error reloading items: \(error.localizedDescription)")
                print("Adding item manually to in-memory collection")
                items.append(newItem)
            }
            
            return newItem
        } catch {
            print("Error saving item: \(error.localizedDescription)")
            throw error
        }
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
        
        // Fuzzy search with relevance scoring
        let scoredItems = items.compactMap { item -> (item: InventoryItem, score: Int)? in
            var score = 0
            
            // Check title with fuzzy matching
            if VolumeExtractor.fuzzyMatches(searchQuery: query, against: item.title) {
                let normalizedQuery = query.lowercased()
                let normalizedTitle = item.title.lowercased()
                
                // Exact match gets highest score
                if normalizedTitle == normalizedQuery {
                    score += 100
                }
                // Starts with query gets high score
                else if normalizedTitle.hasPrefix(normalizedQuery) {
                    score += 80
                }
                // Fuzzy match gets good score
                else {
                    score += 60
                }
            }
            
            // Check series with fuzzy matching
            if let series = item.series,
               VolumeExtractor.fuzzyMatches(searchQuery: query, against: series) {
                let normalizedQuery = query.lowercased()
                let normalizedSeries = series.lowercased()
                
                if normalizedSeries == normalizedQuery {
                    score += 90
                } else if normalizedSeries.hasPrefix(normalizedQuery) {
                    score += 70
                } else {
                    score += 50
                }
            }
            
            // Check author with fuzzy matching
            if let author = item.author,
               VolumeExtractor.fuzzyMatches(searchQuery: query, against: author) {
                let normalizedQuery = query.lowercased()
                let normalizedAuthor = author.lowercased()
                
                if normalizedAuthor == normalizedQuery {
                    score += 60
                } else {
                    score += 30
                }
            }
            
            // ISBN/Barcode exact matches (keep original logic)
            let searchTerm = query.lowercased()
            if let isbn = item.isbn?.lowercased(), isbn.contains(searchTerm) {
                score += 95
            }
            if let barcode = item.barcode?.lowercased(), barcode.contains(searchTerm) {
                score += 95
            }
            
            return score > 0 ? (item, score) : nil
        }
        
        // Sort by score (highest first) then apply volume-aware sorting for items with same score
        let scoreGrouped = Dictionary(grouping: scoredItems) { $0.score }
        
        return scoreGrouped.sorted { $0.key > $1.key }.flatMap { score, items in
            // Within each score group, use hybrid series/volume sorting
            VolumeExtractor.sortInventoryItemsByVolume(items.map { $0.item })
        }
    }
    
    func mangaSeries() -> [(String, [InventoryItem])] {
        return seriesForType(.manga)
    }
    
    /// Generic method to get series for any collection type
    func seriesForType(_ type: CollectionType) -> [(String, [InventoryItem])] {
        guard type.supportsSeriesGrouping else { return [] }
        
        let typeItems = items.filter { $0.type == type }
        let groupingKeyPath = type.seriesGroupingKey
        
        let groupedItems = Dictionary(grouping: typeItems) { item in
            let seriesValue = item[keyPath: groupingKeyPath]
            return cleanupSeriesName(seriesValue) ?? "Unknown Series"
        }
        
        return groupedItems.map { series, seriesItems in
            (
                cleanupSeriesName(series) ?? series,
                seriesItems.sorted { 
                    // Sort by volume number if both have volumes
                    if let vol1 = $0.volume, let vol2 = $1.volume {
                        return vol1 < vol2
                    }
                    // Fallback to title sorting
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
            price: Price(amount: Decimal(14.99)),
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
            price: Price(amount: Decimal(9.99)),
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
            price: Price(amount: Decimal(29.99)),
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
            price: Price(amount: Decimal(59.99)),
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
            price: Price(amount: Decimal(18.99)),
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
        return statsService.hasItemsInLocation(locationId, in: items)
    }
    
    // Handle orphaned items when a location is deleted
    func handleLocationRemoval(_ locationId: UUID) {
        collectionService.handleLocationRemoval(locationId, items: &items, storage: storage)
    }
    
    // Handle location renames (if needed for UI updates)
    func handleLocationRename(_ locationId: UUID, newName: String) {
        collectionService.handleLocationRename(locationId, newName: newName, items: &items, locationManager: locationManager, storage: storage)
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
    func totalValue(for type: CollectionType? = nil) -> Price {
        return statsService.totalValue(for: type, in: items)
    }
    
    func seriesValue(series: String) -> Price {
        return statsService.seriesValue(series: series, in: items)
    }
    
    // Total value of all items
    var totalCollectionValue: Price {
        let total = items.compactMap { $0.price?.amount }.reduce(0, +)
        return Price(amount: total)
    }
    
    // Value by collection type
    func collectionValue(for type: CollectionType) -> Price {
        return statsService.collectionValue(for: type, in: items)
    }
    
    // Value and completion for a specific series
    func seriesStats(name: String) -> (value: Price, count: Int) {
        let stats = statsService.seriesStats(name: name, in: items)
        return (stats.value, stats.count)
    }
    
    // Collection statistics
    var collectionStats: [(type: CollectionType, count: Int, value: Price)] {
        CollectionType.allCases.map { type in
            let typeItems = items.filter { $0.type == type }
            let count = typeItems.count
            let value = typeItems.compactMap { $0.price?.amount }.reduce(0, +)
            return (type, count, Price(amount: value))
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
        
        collectionService.updateItemLocation(item, to: locationId, items: &items, locationManager: locationManager, storage: storage)
        
        // Verify the update through StorageManager
        storage.verifyDatabaseState()
        
        print("Successfully updated item location")
    }
    
    func bulkUpdateItems(items: [InventoryItem], updates: InventoryItem, fields: Set<String>) throws {
        guard !items.isEmpty else {
            throw BulkUpdateError.noItemsSelected
        }
        
        do {
            // Use collection service for bulk update
            let updatedItems = try collectionService.bulkUpdateItems(
                items: items, 
                updates: updates, 
                fields: fields, 
                storage: storage
            )
            
            // Validate items that need validation
            for item in updatedItems {
                if fields.contains("isbn") || fields.contains("title") || 
                   fields.contains("series") || fields.contains("volume") {
                    try validateItem(item, isUpdate: true)
                }
            }
            
            // Reload items to refresh the UI
            self.items = try storage.loadItems()
            
        } catch {
            print("Bulk update failed: \(error.localizedDescription)")
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
        return authorGroupingForType(.books)
    }
    
    /// Generic method to get items grouped by author/creator for any collection type
    func authorGroupingForType(_ type: CollectionType) -> [(String, [InventoryItem])] {
        guard type.supportsAuthorGrouping else { return [] }
        
        let typeItems = items.filter { $0.type == type }
        let groupingKeyPath = type.authorGroupingKey
        
        let groupedItems = Dictionary(grouping: typeItems) { item in
            let authorValue = item[keyPath: groupingKeyPath]
            return cleanupAuthorName(authorValue) ?? "Unknown Author"
        }
        
        return groupedItems.map { author, authorItems in
            (
                cleanupAuthorName(author) ?? author,
                authorItems.sorted { $0.title < $1.title }
            )
        }
        .sorted { $0.0 < $1.0 }
    }
    
    /// Helper method to clean up author names (similar to cleanupSeriesName)
    private func cleanupAuthorName(_ name: String?) -> String? {
        guard let name = name, !name.isEmpty else { return nil }
        var cleaned = name
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: .punctuationCharacters)
        
        // Remove trailing commas and spaces if they exist
        while cleaned.hasSuffix(",") || cleaned.hasSuffix(" ") {
            cleaned = String(cleaned.dropLast())
        }
        
        return cleaned.isEmpty ? nil : cleaned
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
            try collectionService.bulkDeleteItems(with: ids, from: &items, storage: storage)
        } catch {
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
    
    func authorStats(name: String) -> (value: Price, count: Int) {
        let stats = statsService.authorStats(name: name, in: items)
        return (stats.value, stats.count)
    }
    
    func itemsByAuthor(_ author: String) -> [InventoryItem] {
        return searchService.itemsByAuthor(author, from: items)
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
        
        // Safely handle the thumbnail URL
        var thumbnailURL: URL? = nil
        if let thumbnailString = book.volumeInfo.imageLinks?.thumbnail {
            // Make sure we're using https not http
            let secureUrlString = thumbnailString.replacingOccurrences(of: "http://", with: "https://")
            // Add zooming parameter to get larger, correctly-sized images
            let finalUrlString = secureUrlString.replacingOccurrences(of: "&zoom=1", with: "&zoom=0")
            thumbnailURL = URL(string: finalUrlString)
            print("Thumbnail URL: \(finalUrlString)")
        }
        
        // Create the item with safe values for all fields
        let item = InventoryItem(
            title: book.volumeInfo.title,
            type: type,
            series: series,
            volume: volume,
            condition: .good,
            locationId: nil, // Ensure explicit nil for locationId
            barcode: book.volumeInfo.industryIdentifiers?.first?.identifier,
            thumbnailURL: thumbnailURL,
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
    
    public func extractSeriesInfo(from title: String) -> (String?, Int?) {
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
    
    // Update the price calculation methods
    private func calculatePriceStats() {
        let stats = statsService.calculatePriceStats(for: items)
        
        totalValue = stats.totalValue
        averagePrice = stats.averagePrice
        highestPrice = stats.highestPrice
        lowestPrice = stats.lowestPrice
        medianPrice = stats.medianPrice
    }
    
    // Update the price filtering methods
    func itemsWithPriceGreaterThan(_ price: Price) -> [InventoryItem] {
        return searchService.itemsWithPriceGreaterThan(price, from: items)
    }
    
    func itemsWithPriceLessThan(_ price: Price) -> [InventoryItem] {
        return searchService.itemsWithPriceLessThan(price, from: items)
    }
    
    func itemsWithPriceBetween(_ min: Price, and max: Price) -> [InventoryItem] {
        return searchService.itemsWithPriceBetween(min, and: max, from: items)
    }
    
    func itemsWithPriceEqualTo(_ price: Price) -> [InventoryItem] {
        return searchService.itemsWithPriceEqualTo(price, from: items)
    }
    
    // Update the price comparison methods
    func itemsWithPriceAboveAverage() -> [InventoryItem] {
        return searchService.itemsWithPriceAboveAverage(from: items, averagePrice: averagePrice)
    }
    
    // Update the price sorting methods
    func sortByPrice(ascending: Bool = true) {
        items = searchService.sortedByPrice(items, ascending: ascending)
    }
    
    // Update the price range calculation
    func priceRange() -> (min: Price, max: Price)? {
        return statsService.priceRange(for: items)
    }
    
    // Update the price percentile calculation
    func pricePercentile(_ percentile: Double) -> Price? {
        return statsService.pricePercentile(percentile, for: items)
    }
    
    // Update the price statistics calculation
    func priceStatistics() -> (mean: Price, median: Price, mode: Price?)? {
        let prices = items.compactMap { $0.price?.amount }
        guard !prices.isEmpty else { return nil }
        
        let mean = prices.reduce(0, +) / Decimal(prices.count)
        let sorted = prices.sorted()
        let median = sorted[sorted.count / 2]
        
        // Calculate mode
        var frequency: [Decimal: Int] = [:]
        for price in prices {
            frequency[price, default: 0] += 1
        }
        let mode = frequency.max(by: { $0.value < $1.value })?.key
        
        return (
            mean: Price(amount: mean),
            median: Price(amount: median),
            mode: mode.map { Price(amount: $0) }
        )
    }
    
    // Add a refreshItems method to force UI updates
    func refreshItems() {
        do {
            // Reload from storage and explicitly update the @Published property
            // to ensure all views are notified of the change
            items = try storage.loadItems()
        } catch {
            print("Error refreshing items: \(error.localizedDescription)")
        }
    }
} 