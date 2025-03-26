import SwiftUI
import UIKit

class ThumbnailService: ObservableObject {
    @Published private(set) var isLoading = false
    private let googleBooksService = GoogleBooksService()
    private var cache: NSCache<NSString, UIImage> = NSCache()
    private let fileManager = FileManager.default
    
    // Add persistent cache path
    private var cacheDirectory: URL? {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("thumbnails")
    }
    
    init() {
        setupCache()
    }
    
    private func setupCache() {
        // Create thumbnails directory if it doesn't exist
        if let cacheDirectory = cacheDirectory {
            try? fileManager.createDirectory(at: cacheDirectory, 
                                          withIntermediateDirectories: true)
        }
        
        // Configure memory cache
        cache.countLimit = 100 // Maximum number of thumbnails in memory
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB limit
    }
    
    private func processImageURL(_ url: String) -> URL? {
        var urlString = url
        
        // Convert to HTTPS if needed
        if urlString.hasPrefix("http://") {
            urlString = "https://" + urlString.dropFirst(7)
        }
        
        // Handle Google Books specific URL modifications
        if urlString.contains("books.google.com") {
            urlString = urlString.replacingOccurrences(of: "zoom=1", with: "zoom=2")
        }
        
        return URL(string: urlString)
    }
    
    private func cacheKey(for url: URL) -> String {
        url.lastPathComponent + "-" + url.pathComponents.dropLast().last!
    }
    
    func fetchThumbnail(for item: InventoryItem, completion: @escaping (URL?) -> Void) {
        guard item.type.isLiterature else {
            completion(nil)
            return
        }
        
        // Check if we already have a thumbnail URL
        if let existingURL = item.thumbnailURL,
           cache.object(forKey: cacheKey(for: existingURL) as NSString) != nil {
            completion(existingURL)
            return
        }
        
        // Try ISBN first if available
        if let isbn = item.isbn {
            fetchByISBN(isbn: isbn) { url in
                if let url = url {
                    self.downloadAndCacheImage(from: url) { success in
                        completion(success ? url : nil)
                    }
                } else {
                    self.fetchByTitleAndAuthor(item) { url in
                        if let url = url {
                            self.downloadAndCacheImage(from: url) { success in
                                completion(success ? url : nil)
                            }
                        } else {
                            completion(nil)
                        }
                    }
                }
            }
        } else {
            fetchByTitleAndAuthor(item) { url in
                if let url = url {
                    self.downloadAndCacheImage(from: url) { success in
                        completion(success ? url : nil)
                    }
                } else {
                    completion(nil)
                }
            }
        }
    }
    
    private func downloadAndCacheImage(from url: URL, completion: @escaping (Bool) -> Void) {
        let cacheKey = self.cacheKey(for: url) as NSString
        
        // Check disk cache first
        if let image = loadImageFromDisk(fileName: cacheKey as String) {
            cache.setObject(image, forKey: cacheKey)
            completion(true)
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  let image = UIImage(data: data) else {
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            // Cache in memory
            self.cache.setObject(image, forKey: cacheKey)
            
            // Cache to disk
            self.saveImageToDisk(image, fileName: cacheKey as String)
            
            DispatchQueue.main.async {
                completion(true)
            }
        }.resume()
    }
    
    private func loadImageFromDisk(fileName: String) -> UIImage? {
        guard let cacheDirectory = cacheDirectory else { return nil }
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }
    
    private func saveImageToDisk(_ image: UIImage, fileName: String) {
        guard let cacheDirectory = cacheDirectory,
              let data = image.jpegData(compressionQuality: 0.8) else { return }
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        try? data.write(to: fileURL)
    }
    
    private func fetchByTitleAndAuthor(_ item: InventoryItem, completion: @escaping (URL?) -> Void) {
        var searchQuery = item.title
        if let author = item.author {
            searchQuery += " author:\(author)"
        }
        
        googleBooksService.fetchBooks(query: searchQuery) { result in
            switch result {
            case .success(let books):
                if let firstBook = books.first,
                   let thumbnail = firstBook.volumeInfo.imageLinks?.thumbnail,
                   let processedURL = self.processImageURL(thumbnail) {
                    completion(processedURL)
                } else {
                    completion(nil)
                }
            case .failure:
                completion(nil)
            }
        }
    }
    
    private func fetchByISBN(isbn: String, completion: @escaping (URL?) -> Void) {
        googleBooksService.fetchBooks(query: "isbn:\(isbn)") { result in
            switch result {
            case .success(let books):
                if let firstBook = books.first,
                   let thumbnail = firstBook.volumeInfo.imageLinks?.thumbnail,
                   let processedURL = self.processImageURL(thumbnail) {
                    completion(processedURL)
                } else {
                    completion(nil)
                }
            case .failure:
                completion(nil)
            }
        }
    }
    
    func fetchThumbnails(for items: [InventoryItem]) async throws -> [UUID: URL] {
        let results: [UUID: URL] = [:]
        // Implementation...
        return results
    }
} 