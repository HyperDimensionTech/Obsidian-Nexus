import Foundation

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
    
    private var apiKey: String {
        do {
            return try ConfigurationManager.shared.requireString(for: "GoogleBooksAPIKey")
        } catch {
            print("⚠️ Warning: \(error.localizedDescription)")
            return ""
        }
    }
    
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
    
    func fetchBooks(query: String, completion: @escaping (Result<[GoogleBook], Error>) -> Void) {
        // Check cache first
        if let cachedResponse = cache.object(forKey: query as NSString),
           cachedResponse.isValid {
            completion(.success(cachedResponse.books))
            return
        }
        
        isLoading = true
        
        // Determine if query is ISBN
        let formattedQuery: String
        if query.contains("-") || query.replacingOccurrences(of: "-", with: "").count >= 10 {
            formattedQuery = "isbn:" + query.replacingOccurrences(of: "-", with: "")
        } else {
            formattedQuery = query
        }
        
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "q", value: formattedQuery),
            URLQueryItem(name: "maxResults", value: "40"),
            URLQueryItem(name: "key", value: apiKey)
        ]
        
        guard let url = components?.url else {
            completion(.failure(GoogleBooksError.invalidURL))
            isLoading = false
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(GoogleBooksError.noData))
                    return
                }
                
                do {
                    let decodedResponse = try JSONDecoder().decode(GoogleBooksResponse.self, from: data)
                    let books = decodedResponse.items ?? []
                    
                    // Cache the response
                    self?.cache.setObject(CachedResponse(books: books), forKey: query as NSString)
                    
                    completion(.success(books))
                } catch {
                    completion(.failure(error))
                }
            }
        }
        task.resume()
    }
    
    // Helper method to extract volume number from title
    func extractVolumeNumber(from title: String) -> Int? {
        let patterns = [
            "Vol\\.?\\s*(\\d+)",
            "Volume\\s*(\\d+)",
            "V(\\d+)",
            "#(\\d+)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: title, options: [], range: NSRange(title.startIndex..., in: title)) {
                if let range = Range(match.range(at: 1), in: title) {
                    return Int(title[range])
                }
            }
        }
        return nil
    }
}

// MARK: - Errors
enum GoogleBooksError: LocalizedError {
    case invalidURL
    case noData
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL for Google Books API"
        case .noData:
            return "No data received from Google Books API"
        case .decodingError:
            return "Failed to decode response from Google Books API"
        }
    }
} 