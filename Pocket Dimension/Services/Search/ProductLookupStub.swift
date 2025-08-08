import Foundation

final class ProductLookupStub: ProductLookup {
    func search(byBarcode code: String) async throws -> SearchResult? {
        // Placeholder: return nil for now
        return nil
    }
}


