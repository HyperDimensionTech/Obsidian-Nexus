import Foundation

// MARK: - Base Event Protocol

/// Base protocol for all domain events in the system
public protocol DomainEvent: Codable {
    var eventId: UUID { get }
    var aggregateId: UUID { get }
    var timestamp: Date { get }
    var deviceId: DeviceID { get }
    var version: Int { get }
}

// MARK: - Inventory Item Events

/// Events related to inventory item lifecycle
public enum InventoryItemEvent: DomainEvent {
    case created(InventoryItemCreated)
    case updated(InventoryItemUpdated)
    case deleted(InventoryItemDeleted)
    case restored(InventoryItemRestored)
    case locationChanged(InventoryItemLocationChanged)
    
    public var eventId: UUID {
        switch self {
        case .created(let event): return event.eventId
        case .updated(let event): return event.eventId
        case .deleted(let event): return event.eventId
        case .restored(let event): return event.eventId
        case .locationChanged(let event): return event.eventId
        }
    }
    
    public var aggregateId: UUID {
        switch self {
        case .created(let event): return event.aggregateId
        case .updated(let event): return event.aggregateId
        case .deleted(let event): return event.aggregateId
        case .restored(let event): return event.aggregateId
        case .locationChanged(let event): return event.aggregateId
        }
    }
    
    public var timestamp: Date {
        switch self {
        case .created(let event): return event.timestamp
        case .updated(let event): return event.timestamp
        case .deleted(let event): return event.timestamp
        case .restored(let event): return event.timestamp
        case .locationChanged(let event): return event.timestamp
        }
    }
    
    public var deviceId: DeviceID {
        switch self {
        case .created(let event): return event.deviceId
        case .updated(let event): return event.deviceId
        case .deleted(let event): return event.deviceId
        case .restored(let event): return event.deviceId
        case .locationChanged(let event): return event.deviceId
        }
    }
    
    public var version: Int {
        switch self {
        case .created(let event): return event.version
        case .updated(let event): return event.version
        case .deleted(let event): return event.version
        case .restored(let event): return event.version
        case .locationChanged(let event): return event.version
        }
    }
}

/// Event for when a new inventory item is created
public struct InventoryItemCreated: Codable, DomainEvent {
    public let eventId: UUID
    public let aggregateId: UUID
    public let timestamp: Date
    public let deviceId: DeviceID
    public let version: Int
    
    // Core item data
    public let title: String
    public let type: String
    public let series: String?
    public let volume: Int?
    public let condition: String
    public let locationId: UUID?
    public let notes: String?
    public let dateAdded: Date
    public let barcode: String?
    public let thumbnailURL: String?
    
    // Publishing/Creation info
    public let author: String?
    public let manufacturer: String?
    public let originalPublishDate: Date?
    public let publisher: String?
    public let isbn: String?
    public let allISBNs: [String]?
    public let price: Decimal?
    public let priceCurrency: String?
    public let purchaseDate: Date?
    public let synopsis: String?
    
    // Image data
    public let customImageData: Data?
    public let imageSource: String
    
    // Additional v3 fields
    public let serialNumber: String?
    public let modelNumber: String?
    public let character: String?
    public let franchise: String?
    public let dimensions: String?
    public let weight: String?
    public let releaseDate: Date?
    public let limitedEditionNumber: String?
    public let hasOriginalPackaging: Bool?
    public let platform: String?
    public let developer: String?
    public let genre: String?
    public let ageRating: String?
    public let technicalSpecs: String?
    public let warrantyExpiry: Date?
    
    public init(
        aggregateId: UUID,
        deviceId: DeviceID,
        version: Int,
        title: String,
        type: String,
        series: String? = nil,
        volume: Int? = nil,
        condition: String,
        locationId: UUID? = nil,
        notes: String? = nil,
        dateAdded: Date = Date(),
        barcode: String? = nil,
        thumbnailURL: String? = nil,
        author: String? = nil,
        manufacturer: String? = nil,
        originalPublishDate: Date? = nil,
        publisher: String? = nil,
        isbn: String? = nil,
        allISBNs: [String]? = nil,
        price: Decimal? = nil,
        priceCurrency: String? = nil,
        purchaseDate: Date? = nil,
        synopsis: String? = nil,
        customImageData: Data? = nil,
        imageSource: String = "none",
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
        self.eventId = UUID()
        self.aggregateId = aggregateId
        self.timestamp = Date()
        self.deviceId = deviceId
        self.version = version
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
        self.priceCurrency = priceCurrency
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

/// Event for when an inventory item is updated
public struct InventoryItemUpdated: Codable, DomainEvent {
    public let eventId: UUID
    public let aggregateId: UUID
    public let timestamp: Date
    public let deviceId: DeviceID
    public let version: Int
    
    // Updated fields
    public let updatedFields: [String: AnyCodable]
    
    public init(
        aggregateId: UUID,
        deviceId: DeviceID,
        version: Int,
        updatedFields: [String: AnyCodable]
    ) {
        self.eventId = UUID()
        self.aggregateId = aggregateId
        self.timestamp = Date()
        self.deviceId = deviceId
        self.version = version
        self.updatedFields = updatedFields
    }
}

/// Event for when an inventory item is soft-deleted
public struct InventoryItemDeleted: Codable, DomainEvent {
    public let eventId: UUID
    public let aggregateId: UUID
    public let timestamp: Date
    public let deviceId: DeviceID
    public let version: Int
    
    public init(
        aggregateId: UUID,
        deviceId: DeviceID,
        version: Int
    ) {
        self.eventId = UUID()
        self.aggregateId = aggregateId
        self.timestamp = Date()
        self.deviceId = deviceId
        self.version = version
    }
}

/// Event for when an inventory item is restored from deletion
public struct InventoryItemRestored: Codable, DomainEvent {
    public let eventId: UUID
    public let aggregateId: UUID
    public let timestamp: Date
    public let deviceId: DeviceID
    public let version: Int
    
    public init(
        aggregateId: UUID,
        deviceId: DeviceID,
        version: Int
    ) {
        self.eventId = UUID()
        self.aggregateId = aggregateId
        self.timestamp = Date()
        self.deviceId = deviceId
        self.version = version
    }
}

/// Event for when an inventory item's location is changed
public struct InventoryItemLocationChanged: Codable, DomainEvent {
    public let eventId: UUID
    public let aggregateId: UUID
    public let timestamp: Date
    public let deviceId: DeviceID
    public let version: Int
    
    public let previousLocationId: UUID?
    public let newLocationId: UUID?
    
    public init(
        aggregateId: UUID,
        deviceId: DeviceID,
        version: Int,
        previousLocationId: UUID?,
        newLocationId: UUID?
    ) {
        self.eventId = UUID()
        self.aggregateId = aggregateId
        self.timestamp = Date()
        self.deviceId = deviceId
        self.version = version
        self.previousLocationId = previousLocationId
        self.newLocationId = newLocationId
    }
}

// MARK: - Location Events

/// Events related to storage location lifecycle
public enum LocationEvent: DomainEvent {
    case created(LocationCreated)
    case updated(LocationUpdated)
    case deleted(LocationDeleted)
    case parentChanged(LocationParentChanged)
    
    public var eventId: UUID {
        switch self {
        case .created(let event): return event.eventId
        case .updated(let event): return event.eventId
        case .deleted(let event): return event.eventId
        case .parentChanged(let event): return event.eventId
        }
    }
    
    public var aggregateId: UUID {
        switch self {
        case .created(let event): return event.aggregateId
        case .updated(let event): return event.aggregateId
        case .deleted(let event): return event.aggregateId
        case .parentChanged(let event): return event.aggregateId
        }
    }
    
    public var timestamp: Date {
        switch self {
        case .created(let event): return event.timestamp
        case .updated(let event): return event.timestamp
        case .deleted(let event): return event.timestamp
        case .parentChanged(let event): return event.timestamp
        }
    }
    
    public var deviceId: DeviceID {
        switch self {
        case .created(let event): return event.deviceId
        case .updated(let event): return event.deviceId
        case .deleted(let event): return event.deviceId
        case .parentChanged(let event): return event.deviceId
        }
    }
    
    public var version: Int {
        switch self {
        case .created(let event): return event.version
        case .updated(let event): return event.version
        case .deleted(let event): return event.version
        case .parentChanged(let event): return event.version
        }
    }
}

/// Event for when a new location is created
public struct LocationCreated: Codable, DomainEvent {
    public let eventId: UUID
    public let aggregateId: UUID
    public let timestamp: Date
    public let deviceId: DeviceID
    public let version: Int
    
    // Location data
    public let name: String
    public let type: String
    public let parentId: UUID?
    
    public init(
        aggregateId: UUID,
        deviceId: DeviceID,
        version: Int,
        name: String,
        type: String,
        parentId: UUID?
    ) {
        self.eventId = UUID()
        self.aggregateId = aggregateId
        self.timestamp = Date()
        self.deviceId = deviceId
        self.version = version
        self.name = name
        self.type = type
        self.parentId = parentId
    }
}

/// Event for when a location is updated
public struct LocationUpdated: Codable, DomainEvent {
    public let eventId: UUID
    public let aggregateId: UUID
    public let timestamp: Date
    public let deviceId: DeviceID
    public let version: Int
    
    // Updated fields
    public let updatedFields: [String: AnyCodable]
    
    public init(
        aggregateId: UUID,
        deviceId: DeviceID,
        version: Int,
        updatedFields: [String: AnyCodable]
    ) {
        self.eventId = UUID()
        self.aggregateId = aggregateId
        self.timestamp = Date()
        self.deviceId = deviceId
        self.version = version
        self.updatedFields = updatedFields
    }
}

/// Event for when a location is deleted
public struct LocationDeleted: Codable, DomainEvent {
    public let eventId: UUID
    public let aggregateId: UUID
    public let timestamp: Date
    public let deviceId: DeviceID
    public let version: Int
    
    public init(
        aggregateId: UUID,
        deviceId: DeviceID,
        version: Int
    ) {
        self.eventId = UUID()
        self.aggregateId = aggregateId
        self.timestamp = Date()
        self.deviceId = deviceId
        self.version = version
    }
}

/// Event for when a location's parent is changed
public struct LocationParentChanged: Codable, DomainEvent {
    public let eventId: UUID
    public let aggregateId: UUID
    public let timestamp: Date
    public let deviceId: DeviceID
    public let version: Int
    
    public let previousParentId: UUID?
    public let newParentId: UUID?
    
    public init(
        aggregateId: UUID,
        deviceId: DeviceID,
        version: Int,
        previousParentId: UUID?,
        newParentId: UUID?
    ) {
        self.eventId = UUID()
        self.aggregateId = aggregateId
        self.timestamp = Date()
        self.deviceId = deviceId
        self.version = version
        self.previousParentId = previousParentId
        self.newParentId = newParentId
    }
}

// MARK: - ISBN Mapping Events

/// Events related to ISBN mapping lifecycle
public enum ISBNMappingEvent: DomainEvent {
    case created(ISBNMappingCreated)
    case deleted(ISBNMappingDeleted)
    
    public var eventId: UUID {
        switch self {
        case .created(let event): return event.eventId
        case .deleted(let event): return event.eventId
        }
    }
    
    public var aggregateId: UUID {
        switch self {
        case .created(let event): return event.aggregateId
        case .deleted(let event): return event.aggregateId
        }
    }
    
    public var timestamp: Date {
        switch self {
        case .created(let event): return event.timestamp
        case .deleted(let event): return event.timestamp
        }
    }
    
    public var deviceId: DeviceID {
        switch self {
        case .created(let event): return event.deviceId
        case .deleted(let event): return event.deviceId
        }
    }
    
    public var version: Int {
        switch self {
        case .created(let event): return event.version
        case .deleted(let event): return event.version
        }
    }
}

/// Event for when a new ISBN mapping is created
public struct ISBNMappingCreated: Codable, DomainEvent {
    public let eventId: UUID
    public let aggregateId: UUID
    public let timestamp: Date
    public let deviceId: DeviceID
    public let version: Int
    
    // ISBN mapping data
    public let incorrectISBN: String
    public let correctGoogleBooksID: String
    public let title: String
    public let isReprint: Bool
    public let dateAdded: Date
    
    public init(
        aggregateId: UUID,
        deviceId: DeviceID,
        version: Int,
        incorrectISBN: String,
        correctGoogleBooksID: String,
        title: String,
        isReprint: Bool = true,
        dateAdded: Date = Date()
    ) {
        self.eventId = UUID()
        self.aggregateId = aggregateId
        self.timestamp = Date()
        self.deviceId = deviceId
        self.version = version
        self.incorrectISBN = incorrectISBN
        self.correctGoogleBooksID = correctGoogleBooksID
        self.title = title
        self.isReprint = isReprint
        self.dateAdded = dateAdded
    }
}

/// Event for when an ISBN mapping is deleted
public struct ISBNMappingDeleted: Codable, DomainEvent {
    public let eventId: UUID
    public let aggregateId: UUID
    public let timestamp: Date
    public let deviceId: DeviceID
    public let version: Int
    
    public let incorrectISBN: String
    
    public init(
        aggregateId: UUID,
        deviceId: DeviceID,
        version: Int,
        incorrectISBN: String
    ) {
        self.eventId = UUID()
        self.aggregateId = aggregateId
        self.timestamp = Date()
        self.deviceId = deviceId
        self.version = version
        self.incorrectISBN = incorrectISBN
    }
}

// MARK: - Helper Types

/// Type-erased codable wrapper for heterogeneous data
public struct AnyCodable: Codable {
    public let value: Any
    
    public init<T>(_ value: T) where T: Codable {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported type")
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            let codableArray = array.compactMap { value -> AnyCodable? in
                if let codable = value as? Codable {
                    return AnyCodable(codable)
                }
                return nil
            }
            try container.encode(codableArray)
        case let dictionary as [String: Any]:
            let codableDict = dictionary.compactMapValues { value -> AnyCodable? in
                if let codable = value as? Codable {
                    return AnyCodable(codable)
                }
                return nil
            }
            try container.encode(codableDict)
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
} 