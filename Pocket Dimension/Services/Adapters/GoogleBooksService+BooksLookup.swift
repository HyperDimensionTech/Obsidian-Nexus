import Foundation

extension GoogleBooksService: BooksLookup {
    func search(byBarcode code: String) async throws -> SearchResult? {
        // Bridge existing completion-based API using continuation
        return try await withCheckedThrowingContinuation { continuation in
            // Heuristic: if code already contains isbn: prefix, use as-is; else, try ISBN search path
            performISBNSearch(code) { result in
                switch result {
                case .success(let books):
                    // Map first result to SearchResult with conservative confidence
                    if let first = books.first {
                        let identifiers = [
                            "isbn13": first.volumeInfo.industryIdentifiers?.first?.identifier ?? code
                        ]
                        let imageURL = URL(string: first.volumeInfo.imageLinks?.thumbnail ?? "")
                        let creators = first.volumeInfo.authors ?? []
                        let sr = SearchResult(
                            title: first.volumeInfo.title,
                            subtitle: nil,
                            creators: creators,
                            brand: first.volumeInfo.publisher,
                            series: nil,
                            volume: nil,
                            identifiers: identifiers,
                            imageURL: imageURL,
                            description: first.volumeInfo.description,
                            categories: first.volumeInfo.categories ?? [],
                            releaseDate: nil,
                            source: "GoogleBooks",
                            confidence: 0.7
                        )
                        continuation.resume(returning: sr)
                    } else {
                        continuation.resume(returning: nil)
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}


