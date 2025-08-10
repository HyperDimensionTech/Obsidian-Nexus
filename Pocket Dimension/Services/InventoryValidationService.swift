import Foundation

/// Service responsible for validating inventory items and sanitizing user input
@MainActor
class InventoryValidationService {
    
    // MARK: - Validation Errors
    enum ValidationError: LocalizedError {
        case duplicateISBN(String)
        case duplicateInSeries(String, Int)
        case duplicateTitle(String)
        case invalidISBN(String)
        case titleTooLong(String)
        case seriesTooLong(String)
        case authorTooLong(String)
        case publisherTooLong(String)
        case invalidPrice(String)
        case emptyTitle
        
        var errorDescription: String? {
            switch self {
            case .duplicateISBN(let isbn):
                return "An item with ISBN \(isbn) already exists"
            case .duplicateInSeries(let series, let volume):
                return "Volume \(volume) of \(series) already exists"
            case .duplicateTitle(let title):
                return "An item with title '\(title)' already exists"
            case .invalidISBN(let isbn):
                return "Invalid ISBN format: \(isbn)"
            case .titleTooLong(let title):
                return "Title is too long (max 200 characters): \(title.prefix(50))..."
            case .seriesTooLong(let series):
                return "Series name is too long (max 150 characters): \(series.prefix(50))..."
            case .authorTooLong(let author):
                return "Author name is too long (max 150 characters): \(author.prefix(50))..."
            case .publisherTooLong(let publisher):
                return "Publisher name is too long (max 150 characters): \(publisher.prefix(50))..."
            case .invalidPrice(let price):
                return "Invalid price format: \(price)"
            case .emptyTitle:
                return "Title cannot be empty"
            }
        }
    }
    
    // MARK: - Constants
    private let maxTitleLength = 200
    private let maxSeriesLength = 150
    private let maxAuthorLength = 150
    private let maxPublisherLength = 150
    private let maxDescriptionLength = 1000
    
    // MARK: - Input Sanitization
    
    /// Sanitizes text input by removing harmful characters and trimming whitespace
    func sanitizeText(_ text: String?) -> String? {
        guard let text = text, !text.isEmpty else { return nil }
        
        let sanitized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\0", with: "") // Remove null characters
            .replacingOccurrences(of: "\u{FEFF}", with: "") // Remove BOM
            .components(separatedBy: .controlCharacters).joined() // Remove control characters
        
        return sanitized.isEmpty ? nil : sanitized
    }
    
    /// Validates and sanitizes a complete inventory item
    func validateAndSanitizeItem(_ item: InventoryItem, existingItems: [InventoryItem], isUpdate: Bool = false) throws -> InventoryItem {
        // Sanitize all text fields
        let sanitizedTitle = sanitizeText(item.title) ?? ""
        let sanitizedSeries = sanitizeText(item.series)
        let sanitizedAuthor = sanitizeText(item.author)
        let sanitizedPublisher = sanitizeText(item.publisher)
        let sanitizedSynopsis = sanitizeText(item.synopsis)
        let sanitizedISBN = sanitizeText(item.isbn)
        
        // Validate title
        guard !sanitizedTitle.isEmpty else {
            throw ValidationError.emptyTitle
        }
        
        guard sanitizedTitle.count <= maxTitleLength else {
            throw ValidationError.titleTooLong(sanitizedTitle)
        }
        
        // Validate other fields length
        if let series = sanitizedSeries, series.count > maxSeriesLength {
            throw ValidationError.seriesTooLong(series)
        }
        
        if let author = sanitizedAuthor, author.count > maxAuthorLength {
            throw ValidationError.authorTooLong(author)
        }
        
        if let publisher = sanitizedPublisher, publisher.count > maxPublisherLength {
            throw ValidationError.publisherTooLong(publisher)
        }
        
        // Validate ISBN format if provided
        if let isbn = sanitizedISBN {
            try validateISBNFormat(isbn)
        }
        
        // Create sanitized item using the actual InventoryItem initializer
        let sanitizedItem = InventoryItem(
            title: sanitizedTitle,
            type: item.type,
            series: sanitizedSeries,
            volume: item.volume,
            condition: item.condition,
            locationId: item.locationId,
            notes: sanitizeText(item.notes),
            id: item.id,
            dateAdded: item.dateAdded,
            barcode: sanitizeText(item.barcode),
            thumbnailURL: item.thumbnailURL,
            author: sanitizedAuthor,
            manufacturer: sanitizeText(item.manufacturer),
            originalPublishDate: item.originalPublishDate,
            publisher: sanitizedPublisher,
            isbn: sanitizedISBN,
            price: item.price,
            purchaseDate: item.purchaseDate,
            synopsis: sanitizedSynopsis?.count ?? 0 > maxDescriptionLength ? 
                String(sanitizedSynopsis!.prefix(maxDescriptionLength)) : sanitizedSynopsis,
            customImageData: item.customImageData,
            imageSource: item.imageSource,
            serialNumber: sanitizeText(item.serialNumber),
            modelNumber: sanitizeText(item.modelNumber),
            character: sanitizeText(item.character),
            franchise: sanitizeText(item.franchise),
            dimensions: sanitizeText(item.dimensions),
            weight: sanitizeText(item.weight),
            releaseDate: item.releaseDate,
            limitedEditionNumber: sanitizeText(item.limitedEditionNumber),
            hasOriginalPackaging: item.hasOriginalPackaging,
            platform: sanitizeText(item.platform),
            developer: sanitizeText(item.developer),
            genre: sanitizeText(item.genre),
            ageRating: sanitizeText(item.ageRating),
            technicalSpecs: sanitizeText(item.technicalSpecs),
            warrantyExpiry: item.warrantyExpiry
        )
        
        // Validate for duplicates
        try validateForDuplicates(sanitizedItem, existingItems: existingItems, isUpdate: isUpdate)
        
        return sanitizedItem
    }
    
    // MARK: - Duplicate Validation
    
    /// Validates an item for duplicates against existing items
    func validateForDuplicates(_ item: InventoryItem, existingItems: [InventoryItem], isUpdate: Bool = false) throws {
        // For updates, exclude the current item from duplicate checks
        let otherItems = isUpdate ? existingItems.filter({ $0.id != item.id }) : existingItems
        
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
    
    /// Checks if a duplicate exists for the given item
    func duplicateExists(_ item: InventoryItem, existingItems: [InventoryItem]) -> Bool {
        do {
            try validateForDuplicates(item, existingItems: existingItems)
            return false
        } catch {
            return true
        }
    }
    
    // MARK: - Format Validation
    
    /// Validates ISBN-10 or ISBN-13 format
    private func validateISBNFormat(_ isbn: String) throws {
        let cleanISBN = isbn.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "")
        
        guard !cleanISBN.isEmpty else { return }
        
        // Check if it's ISBN-10 or ISBN-13
        if cleanISBN.count == 10 {
            try validateISBN10(cleanISBN)
        } else if cleanISBN.count == 13 {
            try validateISBN13(cleanISBN)
        } else {
            throw ValidationError.invalidISBN(isbn)
        }
    }
    
    private func validateISBN10(_ isbn: String) throws {
        guard isbn.count == 10 else {
            throw ValidationError.invalidISBN(isbn)
        }
        
        // Basic format check - first 9 should be digits, last can be digit or X
        let prefix = String(isbn.prefix(9))
        let checkDigit = String(isbn.suffix(1))
        
        guard prefix.allSatisfy(\.isNumber),
              checkDigit.allSatisfy(\.isNumber) || checkDigit.uppercased() == "X" else {
            throw ValidationError.invalidISBN(isbn)
        }
    }
    
    private func validateISBN13(_ isbn: String) throws {
        guard isbn.count == 13,
              isbn.allSatisfy(\.isNumber) else {
            throw ValidationError.invalidISBN(isbn)
        }
    }
} 