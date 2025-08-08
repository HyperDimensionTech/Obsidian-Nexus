import Foundation

// Simple in-memory cache with TTL for barcode -> identifiers/results
final class CachedMappingStore {
    struct Entry { let value: [String: String]; let expiry: Date }
    private var store: [String: Entry] = [:]
    private let ttl: TimeInterval
    
    init(ttl: TimeInterval = 60 * 60) { // 1 hour default
        self.ttl = ttl
    }
    
    func get(_ code: String) -> [String: String]? {
        clean()
        if let entry = store[code], entry.expiry > Date() { return entry.value }
        return nil
    }
    
    func set(_ code: String, identifiers: [String: String]) {
        store[code] = Entry(value: identifiers, expiry: Date().addingTimeInterval(ttl))
    }
    
    private func clean() {
        let now = Date()
        store = store.filter { $0.value.expiry > now }
    }
}


