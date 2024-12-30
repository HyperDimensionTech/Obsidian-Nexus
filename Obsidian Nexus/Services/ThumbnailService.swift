import Foundation

actor ThumbnailService {
    static let shared = ThumbnailService()
    private let bookService = BookSearchService()
    
    func fetchThumbnail(for item: InventoryItem) async throws -> URL? {
        // If we already have a thumbnail URL, return it
        if let existingURL = item.thumbnailURL {
            return existingURL
        }
        
        // Otherwise, fetch based on type
        switch item.type {
        case .books, .manga:
            return try await fetchBookThumbnail(title: item.title)
        case .comics:
            return try await fetchComicThumbnail(title: item.title)
        case .games:
            return try await fetchGameThumbnail(title: item.title)
        }
    }
    
    private func fetchBookThumbnail(title: String) async throws -> URL? {
        let books = try await bookService.searchBooks(query: title)
        // Get the first book's thumbnail URL
        guard let firstBook = books.first,
              let thumbnailURLString = firstBook.thumbnailURL,
              let url = URL(string: thumbnailURLString) else {
            return nil
        }
        return url
    }
    
    private func fetchComicThumbnail(title: String) async throws -> URL? {
        // TODO: Implement comic API integration
        return nil
    }
    
    private func fetchGameThumbnail(title: String) async throws -> URL? {
        // TODO: Implement game API integration
        return nil
    }
} 