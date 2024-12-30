import Foundation

class StorageManager {
    static let shared = StorageManager()
    
    private let defaults = UserDefaults.standard
    private let itemsKey = "savedInventoryItems"
    
    init() {}
    
    open func save(_ items: [InventoryItem]) throws {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(items)
            defaults.set(data, forKey: itemsKey)
        } catch {
            throw InventoryError.saveFailed
        }
    }
    
    open func load() throws -> [InventoryItem] {
        guard let data = defaults.data(forKey: itemsKey) else {
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode([InventoryItem].self, from: data)
        } catch {
            throw InventoryError.loadFailed
        }
    }
    
    open func clear() {
        defaults.removeObject(forKey: itemsKey)
    }
} 