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
    var price: Price?
    var purchaseDate: Date?
    var synopsis: String?
    
    var customImageData: Data?  // For local images
    var imageSource: ImageSource
    
    // Additional fields for v3
    var serialNumber: String?
    var modelNumber: String?
    var character: String?
    var franchise: String?
    var dimensions: String?
    var weight: String?
    var releaseDate: Date?
    var limitedEditionNumber: String?
    var hasOriginalPackaging: Bool?
    var platform: String?
    var developer: String?
    var genre: String?
    var ageRating: String?
    var technicalSpecs: String?
    var warrantyExpiry: Date?
    
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
    
    enum ImageSource: String, Codable {
        case googleBooks
        case custom
        case none
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
        price: Price? = nil,
        purchaseDate: Date? = nil,
        synopsis: String? = nil,
        customImageData: Data? = nil,
        imageSource: ImageSource = .none,
        serialNumber: String? = nil,
        modelNumber: String? = nil,
        character: String? = nil,
        franchise: String? = nil,
        dimensions: String? = nil,
        weight: String? = nil,
        releaseDate: Date? = nil,
        limitedEditionNumber: String? = nil,
        hasOriginalPackaging: Bool? = nil,
        platform: String? = nil,
        developer: String? = nil,
        genre: String? = nil,
        ageRating: String? = nil,
        technicalSpecs: String? = nil,
        warrantyExpiry: Date? = nil
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
        self.customImageData = customImageData
        self.imageSource = imageSource
        self.serialNumber = serialNumber
        self.modelNumber = modelNumber
        self.character = character
        self.franchise = franchise
        self.dimensions = dimensions
        self.weight = weight
        self.releaseDate = releaseDate
        self.limitedEditionNumber = limitedEditionNumber
        self.hasOriginalPackaging = hasOriginalPackaging
        self.platform = platform
        self.developer = developer
        self.genre = genre
        self.ageRating = ageRating
        self.technicalSpecs = technicalSpecs
        self.warrantyExpiry = warrantyExpiry
    }
} 