import Foundation
import UIKit  // Add this import for UIImage

// MARK: - OpenLibrary Integration Service
/**
 * This service provides integration with the OpenLibrary.org API.
 * Currently implemented but not actively used due to JSON/SwiftUI compatibility challenges.
 *
 * Future Development Plans:
 * 1. Create a local database to cache OpenLibrary data
 * 2. Implement proper data transformation layer to standardize book information
 * 3. Add bulk import functionality for offline access
 * 4. Integrate with existing search once data format is standardized
 *
 * Note: OpenLibrary API returns JSON data that needs significant transformation
 * to match our app's data models. A proper ETL process will be needed before
 * full integration.
 */
class OpenLibraryService: ObservableObject {
    @Published private(set) var isLoading = false
    private let baseURL = "https://openlibrary.org"
    private let searchURL = "https://openlibrary.org/search.json"
    private let coverURL = "https://covers.openlibrary.org/b"
    
    private let cache: NSCache<NSString, CachedResponse> = NSCache()
    private let imageCache: NSCache<NSString, UIImage> = NSCache()
    
    // MARK: - Cache Management
    /**
     * Caching system for API responses and images.
     * Will be expanded when implementing local database.
     *
     * TODO:
     * - Implement persistent storage
     * - Add bulk data caching
     * - Add cache cleanup policies
     */
    private class CachedResponse {
        let data: Any
        let timestamp: Date
        
        init(data: Any) {
            self.data = data
            self.timestamp = Date()
        }
        
        var isValid: Bool {
            return Date().timeIntervalSince(timestamp) < 3600 // 1 hour cache
        }
    }
    
    // MARK: - Search Methods
    /**
     * Searches OpenLibrary.org for books matching the query.
     * Currently implemented but not used in main search flow.
     *
     * Future Enhancements:
     * - Add advanced search filters
     * - Implement proper error handling for all API response cases
     * - Add rate limiting and request queuing
     * - Cache responses in local database
     */
    func searchBooks(query: String) async throws -> OpenLibrarySearchResponse {
        let cleanQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "\(searchURL)?q=\(cleanQuery)") else {
            throw OpenLibraryError.invalidURL
        }
        
        // Check cache first
        if let cached = cache.object(forKey: url.absoluteString as NSString),
           cached.isValid,
           let response = cached.data as? OpenLibrarySearchResponse {
            return response
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OpenLibraryError.invalidResponse
        }
        
        let searchResponse = try JSONDecoder().decode(OpenLibrarySearchResponse.self, from: data)
        cache.setObject(CachedResponse(data: searchResponse), forKey: url.absoluteString as NSString)
        return searchResponse
    }
    
    /**
     * Searches for a book by ISBN.
     * Can be used for direct lookups when scanning barcodes.
     *
     * Future Enhancements:
     * - Add support for multiple ISBN formats
     * - Implement fallback search strategies
     * - Cache results for offline access
     */
    func searchByISBN(_ isbn: String) async throws -> OpenLibraryBook? {
        let cleanISBN = isbn.replacingOccurrences(of: "[^0-9X]", with: "", options: .regularExpression)
        let url = URL(string: "\(baseURL)/api/books?bibkeys=ISBN:\(cleanISBN)&format=json&jscmd=data")!
        
        // Check cache first
        if let cached = cache.object(forKey: url.absoluteString as NSString),
           cached.isValid,
           let book = cached.data as? OpenLibraryBook {
            return book
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OpenLibraryError.invalidResponse
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let bookData = json["ISBN:\(cleanISBN)"] as? [String: Any] {
            let book = try OpenLibraryBook(json: bookData)
            cache.setObject(CachedResponse(data: book), forKey: url.absoluteString as NSString)
            return book
        }
        
        return nil
    }
    
    // MARK: - Author Details
    func fetchAuthorDetails(authorId: String) async throws -> OpenLibraryAuthor {
        let url = URL(string: "\(baseURL)/authors/\(authorId).json")!
        
        if let cached = cache.object(forKey: url.absoluteString as NSString),
           cached.isValid,
           let author = cached.data as? OpenLibraryAuthor {
            return author
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OpenLibraryError.invalidResponse
        }
        
        let author = try JSONDecoder().decode(OpenLibraryAuthor.self, from: data)
        cache.setObject(CachedResponse(data: author), forKey: url.absoluteString as NSString)
        return author
    }
    
    /**
     * Fetches cover images from OpenLibrary.
     * Currently supports basic image loading.
     *
     * Future Enhancements:
     * - Implement proper image caching
     * - Add support for different image sizes
     * - Add placeholder images
     * - Handle missing or corrupt images
     */
    func fetchCoverImage(coverId: Int, size: CoverSize = .medium) async throws -> UIImage {
        let cacheKey = "\(coverId)-\(size.rawValue)" as NSString
        
        if let cachedImage = imageCache.object(forKey: cacheKey) {
            return cachedImage
        }
        
        let url = URL(string: "\(coverURL)/id/\(coverId)-\(size.rawValue).jpg")!
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let image = UIImage(data: data) else {
            throw OpenLibraryError.invalidImage
        }
        
        imageCache.setObject(image, forKey: cacheKey)
        return image
    }
}

// MARK: - Data Models
/**
 * These models represent the raw OpenLibrary.org API response structure.
 * Will need transformation before integration with app models.
 *
 * Future Development:
 * - Add data validation
 * - Implement proper error handling
 * - Add conversion to app's native models
 * - Handle missing or partial data
 */
struct OpenLibrarySearchResponse: Codable {
    let numFound: Int
    let start: Int
    let docs: [OpenLibrarySearchDoc]
    
    // Add convenience computed properties
    var hasResults: Bool { numFound > 0 }
    var nextStart: Int { start + docs.count }
}

struct OpenLibrarySearchDoc: Codable {
    let key: String
    let title: String
    let authorNames: [String]?
    let isbn: [String]?
    let coverId: Int?
    // Add new fields
    let publishYear: Int?
    let publisher: [String]?
    let numberOfPages: Int?
    let subjects: [String]?
    let language: [String]?
    
    enum CodingKeys: String, CodingKey {
        case key, title, isbn, subjects, publisher
        case authorNames = "author_name"
        case coverId = "cover_i"
        case publishYear = "publish_year"
        case numberOfPages = "number_of_pages"
        case language = "language"
    }
    
    // Add convenience computed property for primary ISBN
    var primaryISBN: String? {
        isbn?.first { $0.count == 13 } ?? isbn?.first
    }
}

struct OpenLibraryAuthor: Codable {
    let key: String
    let name: String
    let personalName: String?
    let bio: String?
    let birthDate: String?
    let deathDate: String?  // Add death date
    let works: [OpenLibraryWork]?
    let photos: [Int]?  // Add author photos
    let wikipedia: String?  // Add Wikipedia link
    let links: [AuthorLink]?  // Add external links
    
    enum CodingKeys: String, CodingKey {
        case key, name, bio, works, photos, wikipedia, links
        case personalName = "personal_name"
        case birthDate = "birth_date"
        case deathDate = "death_date"
    }
}

struct AuthorLink: Codable {
    let url: String
    let title: String
}

struct OpenLibraryWork: Codable {
    let key: String
    let title: String
    let coverId: Int?
    let firstPublishYear: Int?
    
    enum CodingKeys: String, CodingKey {
        case key, title
        case coverId = "cover_i"
        case firstPublishYear = "first_publish_year"
    }
}

enum CoverSize: String {
    case small = "S"
    case medium = "M"
    case large = "L"
}

// MARK: - Error Handling
/**
 * Basic error cases for OpenLibrary API.
 * Will be expanded with more specific error cases.
 *
 * Future Enhancements:
 * - Add detailed error messages
 * - Implement retry logic
 * - Add logging
 * - Handle rate limiting
 */
enum OpenLibraryError: LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidImage
    case parsingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .invalidImage:
            return "Failed to load cover image"
        case .parsingError:
            return "Failed to parse response"
        }
    }
}

struct OpenLibraryBook: Codable {
    let title: String
    let authors: [String]?
    let publishDate: String?
    let publisher: String?
    let isbn: String?
    let description: String?  // Add description
    let subjects: [String]?  // Add subjects
    let coverId: Int?  // Add cover ID
    
    init(json: [String: Any]) throws {
        self.title = json["title"] as? String ?? ""
        if let authors = json["authors"] as? [[String: Any]] {
            self.authors = authors.compactMap { $0["name"] as? String }
        } else {
            self.authors = nil
        }
        self.publishDate = json["publish_date"] as? String
        if let publishers = json["publishers"] as? [[String: Any]] {
            self.publisher = publishers.first?["name"] as? String
        } else {
            self.publisher = nil
        }
        if let identifiers = json["identifiers"] as? [String: Any],
           let isbns = identifiers["isbn_13"] as? [String] {
            self.isbn = isbns.first
        } else {
            self.isbn = nil
        }
        self.description = json["description"] as? String
        self.subjects = json["subjects"] as? [String]
        if let covers = json["covers"] as? [Int] {
            self.coverId = covers.first
        } else {
            self.coverId = nil
        }
    }
} 