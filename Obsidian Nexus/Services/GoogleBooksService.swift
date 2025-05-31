import Foundation
import RegexBuilder

// MARK: - Models
struct GoogleBooksResponse: Codable {
    let items: [GoogleBook]?
    let totalItems: Int?
}

struct GoogleBook: Codable, Identifiable {
    let id: String
    let volumeInfo: VolumeInfo
    
    struct VolumeInfo: Codable {
        let title: String
        let authors: [String]?
        let publisher: String?
        let publishedDate: String?
        let description: String?
        let imageLinks: ImageLinks?
        let industryIdentifiers: [IndustryIdentifier]?
        let pageCount: Int?
        let categories: [String]?
        let averageRating: Double?
        let ratingsCount: Int?
        let language: String?
        let mainCategory: String?
        
        struct ImageLinks: Codable {
            let smallThumbnail: String?
            let thumbnail: String?
            let small: String?
            let medium: String?
            let large: String?
            let extraLarge: String?
        }
        
        struct IndustryIdentifier: Codable {
            let type: String
            let identifier: String
        }
    }
}

// MARK: - Service
class GoogleBooksService: ObservableObject {
    @Published private(set) var isLoading = false
    private let cache: NSCache<NSString, CachedResponse> = NSCache()
    private let openLibraryService = OpenLibraryService()
    
    private let apiKey = "AIzaSyDpVBfeY4TNKgOX3n4e_wD13_qYgjQVM8Y"
    private let baseURL = "https://www.googleapis.com/books/v1/volumes"
    
    // Cache response class
    private class CachedResponse {
        let books: [GoogleBook]
        let timestamp: Date
        
        init(books: [GoogleBook]) {
            self.books = books
            self.timestamp = Date()
        }
        
        var isValid: Bool {
            // Cache valid for 1 hour
            return Date().timeIntervalSince(timestamp) < 3600
        }
    }
    
    // MARK: - Advanced Query Building
    
    private func buildOptimizedSearchQuery(_ query: String) -> String {
        guard !query.isEmpty else { return "" }
        
        // Check if it's an ISBN first
        if let isbnQuery = buildISBNQuery(query) {
            return isbnQuery
        }
        
        // For manga titles, add manga keyword
        let cleanQuery = query.trimmingCharacters(in: .whitespaces)
        if PublisherType.manga.searchKeywords.contains(where: { cleanQuery.lowercased().contains($0) }) {
            return "\(cleanQuery) manga"
        }
        
        // For academic or technical books, add subject filters
        if cleanQuery.lowercased().contains("programming") ||
           cleanQuery.lowercased().contains("software") ||
           cleanQuery.lowercased().contains("computer") {
            return "subject:computers \(cleanQuery)"
        }
        
        return cleanQuery
    }
    
    private func buildISBNQuery(_ query: String) -> String? {
        // Handle explicit ISBN format
        if query.lowercased().contains("isbn:") {
            let isbn = query.replacingOccurrences(of: "(?i)isbn:", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            if isValidISBN(isbn) {
                return "isbn:\(isbn)"
            }
        }
        
        // Handle raw ISBN numbers
        if query.allSatisfy({ $0.isNumber }) && isValidISBN(query) {
            return "isbn:\(query)"
        }
        
        return nil
    }
    
    private func buildSearchQuery(_ query: String) -> String {
        return buildOptimizedSearchQuery(query)
    }
    
    private func isValidISBN(_ isbn: String) -> Bool {
        let cleanISBN = isbn.replacingOccurrences(of: "[^0-9X]", with: "", options: .regularExpression)
        return cleanISBN.count == 10 || cleanISBN.count == 13
    }
    
    // MARK: - Enhanced Search Methods
    
    func fetchBooks(query: String, completion: @escaping (Result<[GoogleBook], Error>) -> Void) {
        guard !query.isEmpty else {
            print("DEBUG: Empty query received")
            completion(.failure(GoogleBooksError.emptyQuery))
            return
        }
        
        // Try multiple search strategies for better results
        performMultiStrategySearch(query: query, completion: completion)
    }
    
    private func performMultiStrategySearch(query: String, completion: @escaping (Result<[GoogleBook], Error>) -> Void) {
        let formattedQuery = buildSearchQuery(query)
        print("DEBUG: Original query: \(query)")
        print("DEBUG: Formatted query: \(formattedQuery)")
        
        // First attempt with optimized parameters
        performSearchWithParams(
            query: formattedQuery,
            maxResults: 40,
            projection: "full",
            orderBy: "relevance"
        ) { [weak self] result in
            switch result {
            case .success(let books):
                if !books.isEmpty {
                    completion(.success(books))
                } else {
                    // Fallback: try broader search with different parameters
                    self?.performFallbackSearch(originalQuery: query, completion: completion)
                }
            case .failure(let error):
                print("DEBUG: Primary search failed: \(error)")
                self?.performFallbackSearch(originalQuery: query, completion: completion)
            }
        }
    }
    
    private func performFallbackSearch(originalQuery: String, completion: @escaping (Result<[GoogleBook], Error>) -> Void) {
        print("DEBUG: Performing fallback search for: \(originalQuery)")
        
        // If original was ISBN search, try title search
        if originalQuery.lowercased().contains("isbn:") || originalQuery.allSatisfy({ $0.isNumber }) {
            let broadQuery = originalQuery.replacingOccurrences(of: "(?i)isbn:", with: "", options: .regularExpression)
            performSearchWithParams(
                query: broadQuery,
                maxResults: 20,
                projection: "full",
                orderBy: "relevance"
            ) { result in
                completion(result)
            }
        } else {
            // Try different ordering for regular searches
            performSearchWithParams(
                query: originalQuery,
                maxResults: 20,
                projection: "lite",
                orderBy: "newest"
            ) { result in
                completion(result)
            }
        }
    }
    
    private func performSearchWithParams(
        query: String,
        maxResults: Int,
        projection: String,
        orderBy: String,
        completion: @escaping (Result<[GoogleBook], Error>) -> Void
    ) {
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "maxResults", value: String(maxResults)),
            URLQueryItem(name: "projection", value: projection),
            URLQueryItem(name: "orderBy", value: orderBy),
            URLQueryItem(name: "printType", value: "books"),
            URLQueryItem(name: "key", value: apiKey)
        ]
        
        guard let url = components?.url else {
            print("DEBUG: Failed to construct URL")
            completion(.failure(GoogleBooksError.invalidURL))
            return
        }
        
        print("DEBUG: Search URL: \(url.absoluteString)")
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    print("DEBUG: Network error: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("DEBUG: Invalid response type")
                    completion(.failure(GoogleBooksError.invalidResponse))
                    return
                }
                
                print("DEBUG: Response status code: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    if let data = data,
                       let response = try? JSONDecoder().decode(GoogleBooksResponse.self, from: data) {
                        let books = response.items ?? []
                        print("DEBUG: Found \(books.count) books (Total: \(response.totalItems ?? 0))")
                        completion(.success(books))
                    } else {
                        print("DEBUG: Failed to decode response")
                        if let data = data, let responseString = String(data: data, encoding: .utf8) {
                            print("DEBUG: Raw response: \(String(responseString.prefix(500)))")
                        }
                        completion(.failure(GoogleBooksError.invalidResponse))
                    }
                } else {
                    print("DEBUG: API error with status code: \(httpResponse.statusCode)")
                    completion(.failure(GoogleBooksError.apiError("Status code: \(httpResponse.statusCode)")))
                }
            }
        }
        task.resume()
    }
    
    // MARK: - Enhanced ISBN Search with Multiple Strategies
    
    func performISBNSearch(_ isbn: String, completion: @escaping (Result<[GoogleBook], Error>) -> Void) {
        print("DEBUG: Starting enhanced ISBN search for: \(isbn)")
        
        // Strategy 1: Direct ISBN search
        performSearchWithParams(
            query: "isbn:\(isbn)",
            maxResults: 10,
            projection: "full",
            orderBy: "relevance"
        ) { [weak self] result in
            switch result {
            case .success(let books):
                if !books.isEmpty {
                    print("DEBUG: ISBN search successful, found \(books.count) books")
                    completion(.success(books))
                } else {
                    // Strategy 2: Try without isbn: prefix
                    print("DEBUG: No results with isbn: prefix, trying raw number")
                    self?.performSearchWithParams(
                        query: isbn,
                        maxResults: 10,
                        projection: "full",
                        orderBy: "relevance"
                    ) { fallbackResult in
                        completion(fallbackResult)
                    }
                }
            case .failure(let error):
                print("DEBUG: ISBN search failed: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Enhanced Title Search
    
    func performTitleSearch(_ title: String, completion: @escaping (Result<[GoogleBook], Error>) -> Void) {
        print("DEBUG: Starting enhanced title search for: \(title)")
        
        // Use intitle: for more precise title matching
        let titleQuery = "intitle:\"\(title)\""
        
        performSearchWithParams(
            query: titleQuery,
            maxResults: 40,
            projection: "full",
            orderBy: "relevance"
        ) { [weak self] result in
            switch result {
            case .success(let books):
                if !books.isEmpty {
                    completion(.success(books))
                } else {
                    // Fallback: try without quotes and intitle
                    print("DEBUG: No exact title match, trying broader search")
                    self?.performSearchWithParams(
                        query: title,
                        maxResults: 20,
                        projection: "full",
                        orderBy: "relevance"
                    ) { fallbackResult in
                        completion(fallbackResult)
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Multi-field Search
    
    func performMultiFieldSearch(title: String?, author: String?, publisher: String?, completion: @escaping (Result<[GoogleBook], Error>) -> Void) {
        var queryParts: [String] = []
        
        if let title = title, !title.isEmpty {
            queryParts.append("intitle:\"\(title)\"")
        }
        
        if let author = author, !author.isEmpty {
            queryParts.append("inauthor:\"\(author)\"")
        }
        
        if let publisher = publisher, !publisher.isEmpty {
            queryParts.append("inpublisher:\"\(publisher)\"")
        }
        
        let combinedQuery = queryParts.joined(separator: " ")
        
        performSearchWithParams(
            query: combinedQuery,
            maxResults: 40,
            projection: "full",
            orderBy: "relevance",
            completion: completion
        )
    }
    
    // Helper method to extract volume number from title
    func extractVolumeNumber(from title: String) -> Int? {
        // Define patterns without try
        let patterns = [
            Regex {
                OneOrMore(.whitespace)
                Capture {
                    OneOrMore(.digit)
                }
                Anchor.endOfLine
            },
            Regex {
                ChoiceOf {
                    "Vol"
                    "vol"
                    "VOL"
                }
                Optionally(".")
                OneOrMore(.whitespace)
                Capture {
                    OneOrMore(.digit)
                }
            }
        ]  // Remove compactMap since patterns won't fail
        
        for pattern in patterns {
            if let match = try? pattern.firstMatch(in: title),
               let number = Int(match.1.description) {
                return number
            }
        }
        return nil
    }
    
    // Fetch a book directly by its Google Books ID
    func fetchBookById(_ id: String, completion: @escaping (Result<GoogleBook, Error>) -> Void) {
        guard !id.isEmpty else {
            completion(.failure(GoogleBooksError.emptyQuery))
            return
        }
        
        let urlString = "\(baseURL)/\(id)?projection=full&key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(GoogleBooksError.invalidURL))
            return
        }
        
        print("DEBUG: Fetching book by ID: \(id)")
        print("DEBUG: URL: \(urlString)")
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("DEBUG: Network error: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(GoogleBooksError.invalidResponse))
                    return
                }
                
                print("DEBUG: Response status code: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    if let data = data,
                       let book = try? JSONDecoder().decode(GoogleBook.self, from: data) {
                        print("DEBUG: Successfully fetched book: \(book.volumeInfo.title)")
                        completion(.success(book))
                    } else {
                        print("DEBUG: Failed to decode book")
                        if let data = data, let responseString = String(data: data, encoding: .utf8) {
                            print("DEBUG: Raw response: \(String(responseString.prefix(500)))")
                        }
                        completion(.failure(GoogleBooksError.invalidResponse))
                    }
                } else {
                    print("DEBUG: API error with status code: \(httpResponse.statusCode)")
                    completion(.failure(GoogleBooksError.apiError("Status code: \(httpResponse.statusCode)")))
                }
            }
        }
        task.resume()
    }
    
    private func searchWithFallback(isbn: String, completion: @escaping (Result<[GoogleBook], Error>) -> Void) {
        Task {
            do {
                if let openLibraryBook = try await openLibraryService.searchByISBN(isbn) {
                    // Convert OpenLibraryBook to GoogleBook format
                    let book = GoogleBook(
                        id: isbn,
                        volumeInfo: .init(
                            title: openLibraryBook.title,
                            authors: openLibraryBook.authors,
                            publisher: openLibraryBook.publisher,
                            publishedDate: openLibraryBook.publishDate,
                            description: nil,
                            imageLinks: nil,
                            industryIdentifiers: [
                                .init(type: "ISBN_13", identifier: isbn)
                            ],
                            pageCount: nil,
                            categories: nil,
                            averageRating: nil,
                            ratingsCount: nil,
                            language: nil,
                            mainCategory: nil
                        )
                    )
                    completion(.success([book]))
                } else {
                    completion(.success([]))
                }
            } catch {
                completion(.failure(error))
            }
        }
    }
}

// MARK: - Error Types
enum GoogleBooksError: Error {
    case emptyQuery
    case invalidURL
    case invalidResponse
    case apiError(String)
} 