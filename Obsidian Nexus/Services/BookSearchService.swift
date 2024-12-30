import Foundation

class BookSearchService {
    private let baseURL = "https://www.googleapis.com/books/v1/volumes"
    
    func searchBooks(query: String) async throws -> [Book] {
        guard let url = URL(string: "\(baseURL)?q=\(query)") else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(GoogleBooksResponse.self, from: data)
        return response.items.map { Book(from: $0.volumeInfo) }
    }
}

struct GoogleBooksResponse: Codable {
    let items: [VolumeInfo]
}

struct VolumeInfo: Codable {
    let volumeInfo: BookInfo
}

struct BookInfo: Codable {
    let title: String
    let authors: [String]?
    let publishedDate: String?
    let industryIdentifiers: [ISBN]?
    let imageLinks: ImageLinks?
}

struct ISBN: Codable {
    let type: String
    let identifier: String
}

struct Book {
    let title: String
    let authors: [String]
    let isbn: String?
    let publishedDate: String?
    let thumbnailURL: String?
    
    init(from volumeInfo: BookInfo) {
        self.title = volumeInfo.title
        self.authors = volumeInfo.authors ?? []
        self.isbn = volumeInfo.industryIdentifiers?.first?.identifier
        self.publishedDate = volumeInfo.publishedDate
        self.thumbnailURL = volumeInfo.imageLinks?.thumbnail
    }
}

struct ImageLinks: Codable {
    let thumbnail: String
    let smallThumbnail: String?
} 