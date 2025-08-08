import Foundation

struct DashboardData {
    static func collectionDetails(for type: CollectionType) -> (title: String, description: String) {
        (title: "\(type.name) Collection", description: type.description)
    }
    
    static var allCollectionDetails: [(title: String, description: String)] {
        CollectionType.allCases.map { type in
            collectionDetails(for: type)
        }
    }
} 