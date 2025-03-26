import Foundation

enum LocationType: String, Codable, CaseIterable {
    case room
    case shelf
    case cabinet
    case drawer
    case box
    
    var icon: String {
        switch self {
        case .room: return "house"
        case .shelf: return "books.vertical"
        case .cabinet: return "cabinet"
        case .drawer: return "tray"
        case .box: return "shippingbox"
        }
    }
} 