import Foundation

enum ItemType: String, CaseIterable, Identifiable, Codable {
    case books
    case manga
    case comics
    case games
    case other
    
    var id: String { rawValue }
    
    var name: String {
        rawValue.capitalized
    }
} 