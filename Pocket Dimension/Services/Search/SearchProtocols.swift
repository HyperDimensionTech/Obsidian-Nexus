import Foundation

// MARK: - Code Type
public enum CodeType {
    case isbn10
    case isbn13
    case ean13
    case upcA
    case qr
    case unknown
}

public protocol CodeTypeDetector {
    func detect(from raw: String) -> CodeType
}

// MARK: - Search Provider
public protocol SearchProvider {
    func search(byBarcode code: String) async throws -> SearchResult?
}

// MARK: - Search Result
public struct SearchResult {
    public var title: String
    public var subtitle: String?
    public var creators: [String]
    public var brand: String?
    public var series: String?
    public var volume: String?
    public var identifiers: [String: String]
    public var imageURL: URL?
    public var description: String?
    public var categories: [String]
    public var releaseDate: Date?
    public var source: String
    public var confidence: Double

    public init(
        title: String,
        subtitle: String? = nil,
        creators: [String] = [],
        brand: String? = nil,
        series: String? = nil,
        volume: String? = nil,
        identifiers: [String: String] = [:],
        imageURL: URL? = nil,
        description: String? = nil,
        categories: [String] = [],
        releaseDate: Date? = nil,
        source: String,
        confidence: Double
    ) {
        self.title = title
        self.subtitle = subtitle
        self.creators = creators
        self.brand = brand
        self.series = series
        self.volume = volume
        self.identifiers = identifiers
        self.imageURL = imageURL
        self.description = description
        self.categories = categories
        self.releaseDate = releaseDate
        self.source = source
        self.confidence = confidence
    }
}


