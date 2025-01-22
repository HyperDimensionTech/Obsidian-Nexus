import Foundation

struct InventoryItem: Identifiable, Codable {
    let id: UUID
    var title: String
    var type: CollectionType
    var series: String?
    var volume: Int?
    var condition: ItemCondition
    var locationId: UUID?
    var notes: String?
    var dateAdded: Date
    var barcode: String?
    var thumbnailURL: URL?
    
    // New fields
    var author: String?
    var manufacturer: String?
    var originalPublishDate: Date?
    var publisher: String?
    var isbn: String?
    var price: Decimal?
    var purchaseDate: Date?
    var synopsis: String?
    
    var creator: String? {
        switch type {
        case .books, .manga, .comics:
            return author
        case .games:
            return manufacturer
        case .collectibles:
            // Handle collectibles case
            return nil
        case .electronics:
            // Handle electronics case
            return nil
        case .tools:
            // Handle tools case
            return nil
        }
    }
    
    init(
        title: String,
        type: CollectionType,
        series: String? = nil,
        volume: Int? = nil,
        condition: ItemCondition = .good,
        locationId: UUID? = nil,
        notes: String? = nil,
        id: UUID = UUID(),
        dateAdded: Date = Date(),
        barcode: String? = nil,
        thumbnailURL: URL? = nil,
        author: String? = nil,
        manufacturer: String? = nil,
        originalPublishDate: Date? = nil,
        publisher: String? = nil,
        isbn: String? = nil,
        price: Decimal? = nil,
        purchaseDate: Date? = nil,
        synopsis: String? = nil
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.series = series
        self.volume = volume
        self.condition = condition
        self.locationId = locationId
        self.notes = notes
        self.dateAdded = dateAdded
        self.barcode = barcode
        self.thumbnailURL = thumbnailURL
        self.author = author
        self.manufacturer = manufacturer
        self.originalPublishDate = originalPublishDate
        self.publisher = publisher
        self.isbn = isbn
        self.price = price
        self.purchaseDate = purchaseDate
        self.synopsis = synopsis
    }
} 