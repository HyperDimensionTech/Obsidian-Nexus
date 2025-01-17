import Foundation
import SwiftUI

@MainActor
class CollectionManager: ObservableObject {
    @Published private(set) var collections: [Collection] = []
    private let collectionsKey = "collections"
    
    init() {
        loadCollections()
    }
    
    func addCollection(_ collection: Collection) {
        collections.append(collection)
        saveCollections()
    }
    
    func deleteCollection(_ collection: Collection) {
        collections.removeAll { $0.id == collection.id }
        saveCollections()
    }
    
    private func loadCollections() {
        if let data = UserDefaults.standard.data(forKey: collectionsKey) {
            do {
                collections = try JSONDecoder().decode([Collection].self, from: data)
            } catch {
                print("Failed to decode collections: \(error)")
                createDefaultCollection()
            }
        } else {
            createDefaultCollection()
        }
    }
    
    private func saveCollections() {
        do {
            let data = try JSONEncoder().encode(collections)
            UserDefaults.standard.set(data, forKey: collectionsKey)
        } catch {
            print("Failed to save collections: \(error)")
        }
    }
    
    private func createDefaultCollection() {
        let defaultCollection = Collection(
            name: "My Collection",
            description: "Default collection for all items",
            type: .books
        )
        collections = [defaultCollection]
        saveCollections()
    }
    
    func isItemInCollection(_ itemId: UUID, collectionId: UUID) -> Bool {
        guard let collection = collections.first(where: { $0.id == collectionId }) else {
            return false
        }
        
        return collection.itemIds.contains(itemId)
    }
    
    func addItemToCollection(_ itemId: UUID, collectionId: UUID) {
        if var collection = collections.first(where: { $0.id == collectionId }) {
            collection.itemIds.append(itemId)
            if let index = collections.firstIndex(where: { $0.id == collectionId }) {
                collections[index] = collection
            }
            saveCollections()
        }
    }
} 