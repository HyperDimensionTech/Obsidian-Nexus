import Foundation
@testable import Obsidian_Nexus

class MockStorageManager: StorageManager {
    var savedItems: [InventoryItem] = []
    var shouldFail = false
    
    override func save(_ items: [InventoryItem]) throws {
        if shouldFail {
            throw InventoryError.saveFailed
        }
        savedItems = items
    }
    
    override func load() throws -> [InventoryItem] {
        if shouldFail {
            throw InventoryError.loadFailed
        }
        return savedItems
    }
    
    override func clear() {
        savedItems = []
    }
} 