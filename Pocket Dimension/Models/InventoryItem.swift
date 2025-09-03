import Foundation

public struct InventoryItem: Identifiable, Codable {
    public let id: UUID
    public var title: String
    public var type: CollectionType
    public var series: String?
    public var volume: Int?
    public var condition: ItemCondition
    public var locationId: UUID?
    public var notes: String?
    public var dateAdded: Date
    public var barcode: String?
    public var thumbnailURL: URL?
    
    // New fields
    public var author: String?
    public var manufacturer: String?
    public var originalPublishDate: Date?
    public var publisher: String?
    public var isbn: String? // Primary ISBN for backward compatibility
    public var allISBNs: [String]? // All ISBN variants (ISBN-10, ISBN-13, etc.)
    public var price: Price?
    public var purchaseDate: Date?
    public var synopsis: String?
    
    public var customImageData: Data?  // For local images
    public var imageSource: ImageSource
    
    // Additional fields for v3
    public var serialNumber: String?
    public var modelNumber: String?
    public var character: String?
    public var franchise: String?
    public var dimensions: String?
    public var weight: String?
    public var releaseDate: Date?
    public var limitedEditionNumber: String?
    public var hasOriginalPackaging: Bool?
    public var platform: String?
    public var developer: String?
    public var genre: String?
    public var ageRating: String?
    public var technicalSpecs: String?
    public var warrantyExpiry: Date?
    
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
    
    /// Returns all ISBN variants for this item, including the primary ISBN
    var allISBNVariants: [String] {
        var isbns: [String] = []
        
        // Add primary ISBN if exists
        if let primaryISBN = isbn, !primaryISBN.isEmpty {
            isbns.append(primaryISBN)
        }
        
        // Add additional ISBNs if exists
        if let additionalISBNs = allISBNs {
            isbns.append(contentsOf: additionalISBNs.filter { !$0.isEmpty && !isbns.contains($0) })
        }
        
        return isbns
    }
    
    public enum ImageSource: String, Codable {
        case googleBooks
        case custom
        case none
    }
    
    public init(
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
        allISBNs: [String]? = nil,
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
        self.allISBNs = allISBNs
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