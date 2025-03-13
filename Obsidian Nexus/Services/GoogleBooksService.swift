import Foundation
import RegexBuilder

// MARK: - Models
struct GoogleBooksResponse: Codable {
    let items: [GoogleBook]?
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
        
        struct ImageLinks: Codable {
            let smallThumbnail: String?
            let thumbnail: String?
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
    
    private func buildSearchQuery(_ query: String) -> String {
        guard !query.isEmpty else { return "" }
        
        // ISBN handling
        if query.lowercased().contains("isbn:") || query.allSatisfy({ $0.isNumber }) {
            let isbn = query.replacingOccurrences(of: "(?i)isbn:", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            if isValidISBN(isbn) {
                print("DEBUG: Searching with ISBN: \(isbn)") // Debug log
                return "isbn:\(isbn)"
            }
        }
        
        // For manga titles, append manga
        let cleanQuery = query.trimmingCharacters(in: .whitespaces)
        if PublisherType.manga.searchKeywords.contains(where: { cleanQuery.lowercased().contains($0) }) {
            return "\(cleanQuery) manga"
        }
        
        return cleanQuery
    }
    
    private func isValidISBN(_ isbn: String) -> Bool {
        let cleanISBN = isbn.replacingOccurrences(of: "[^0-9X]", with: "", options: .regularExpression)
        return cleanISBN.count == 10 || cleanISBN.count == 13
    }
    
    func fetchBooks(query: String, completion: @escaping (Result<[GoogleBook], Error>) -> Void) {
        guard !query.isEmpty else {
            print("DEBUG: Empty query received")
            completion(.failure(GoogleBooksError.emptyQuery))
            return
        }
        
        let formattedQuery = buildSearchQuery(query)
        print("DEBUG: Original query: \(query)")
        print("DEBUG: Formatted query: \(formattedQuery)")
        
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "q", value: formattedQuery),
            URLQueryItem(name: "maxResults", value: "40"),
            URLQueryItem(name: "key", value: apiKey)
        ]
        
        guard let url = components?.url else {
            print("DEBUG: Failed to construct URL")
            completion(.failure(GoogleBooksError.invalidURL))
            isLoading = false
            return
        }
        
        print("DEBUG: Final URL: \(url.absoluteString)")
        
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
                        print("DEBUG: Found \(books.count) books")
                        
                        // If ISBN search returns no results, try a more general search
                        if books.isEmpty && query.lowercased().contains("isbn:") {
                            print("DEBUG: No results for ISBN, trying general search")
                            let isbn = query.replacingOccurrences(of: "(?i)isbn:", with: "", options: .regularExpression)
                            
                            // Try searching without the isbn: prefix
                            let fallbackQuery = isbn
                            print("DEBUG: Trying fallback query: \(fallbackQuery)")
                            self?.fetchBooks(query: fallbackQuery, completion: completion)
                            return
                        }
                        
                        completion(.success(books))
                    } else {
                        print("DEBUG: Failed to decode response")
                        if let data = data, let responseString = String(data: data, encoding: .utf8) {
                            print("DEBUG: Raw response: \(responseString)")
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
        
        let urlString = "\(baseURL)/\(id)?key=\(apiKey)"
        
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
                            print("DEBUG: Raw response: \(responseString)")
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
                            ]
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
    
    // Fetch books by ISBN
    func fetchBooksByISBN(_ isbn: String, completion: @escaping (Result<[GoogleBook], Error>) -> Void) {
        // Clean the ISBN by removing any non-numeric characters
        let cleanedISBN = isbn.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        // Check if we have a cached result
        let cacheKey = NSString(string: "isbn:\(cleanedISBN)")
        if let cachedResponse = cache.object(forKey: cacheKey), cachedResponse.isValid {
            completion(.success(cachedResponse.books))
            return
        }
        
        // Set loading state
        isLoading = true
        
        // Build the query URL
        let query = "isbn:\(cleanedISBN)"
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)?q=\(encodedQuery)&maxResults=10&key=\(apiKey)") else {
            isLoading = false
            completion(.failure(GoogleBooksError.invalidURL))
            return
        }
        
        // Make the network request
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // Reset loading state
            DispatchQueue.main.async {
                self.isLoading = false
            }
            
            // Handle network errors
            if let error = error {
                print("Network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            // Check for valid response
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response")
                completion(.failure(GoogleBooksError.invalidResponse))
                return
            }
            
            // Check for HTTP errors
            if httpResponse.statusCode != 200 {
                print("HTTP error: \(httpResponse.statusCode)")
                completion(.failure(GoogleBooksError.httpError(httpResponse.statusCode)))
                return
            }
            
            // Check for data
            guard let data = data else {
                print("No data received")
                completion(.failure(GoogleBooksError.noData))
                return
            }
            
            // Parse the JSON response
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(GoogleBooksResponse.self, from: data)
                let books = response.items ?? []
                
                // Cache the result
                DispatchQueue.main.async {
                    let cachedResponse = CachedResponse(books: books)
                    self.cache.setObject(cachedResponse, forKey: cacheKey)
                }
                
                completion(.success(books))
            } catch {
                print("JSON decoding error: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
    }
}

// MARK: - Errors
enum GoogleBooksError: LocalizedError {
    case emptyQuery
    case invalidResponse
    case apiError(String)
    case invalidISBN
    case noData
    case invalidURL
    case httpError(Int)
    
    var errorDescription: String? {
        switch self {
        case .emptyQuery:
            return "Please enter a search term"
        case .invalidResponse:
            return "Unable to process the search results"
        case .apiError(let message):
            return "API Error: \(message)"
        case .invalidISBN:
            return "Invalid ISBN format"
        case .noData:
            return "No data received"
        case .invalidURL:
            return "Invalid URL for Google Books API"
        case .httpError(let code):
            return "HTTP Error: \(code)"
        }
    }
} 