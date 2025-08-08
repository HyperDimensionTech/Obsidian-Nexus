import Foundation

public protocol SearchRouting {
    func search(byBarcode code: String) async throws -> SearchResult?
}

final class SearchRouter: SearchRouting {
    private let detector: CodeTypeDetector
    private let books: BooksLookup
    private let products: ProductLookup
    private let minConfidence: Double
    
    init(detector: CodeTypeDetector, books: BooksLookup, products: ProductLookup, minConfidence: Double = 0.2) {
        self.detector = detector
        self.books = books
        self.products = products
        self.minConfidence = minConfidence
    }
    
    func search(byBarcode code: String) async throws -> SearchResult? {
        let type = detector.detect(from: code)
        let result: SearchResult?
        switch type {
        case .isbn10, .isbn13:
            result = try await books.search(byBarcode: code)
        case .ean13, .upcA:
            result = try await products.search(byBarcode: code)
        case .qr, .unknown:
            result = nil
        }
        guard let r = result, r.confidence >= minConfidence else { return nil }
        return r
    }
}


