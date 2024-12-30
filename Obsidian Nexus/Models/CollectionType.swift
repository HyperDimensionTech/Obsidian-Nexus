import SwiftUI

enum CollectionType: String, CaseIterable, Identifiable, Codable {
    case manga
    case books
    case comics
    case games
    
    var id: String { rawValue }
    
    var name: String {
        rawValue.capitalized
    }
    
    var description: String {
        switch self {
        case .manga: return "Japanese comics and graphic novels"
        case .books: return "Novels, textbooks, and reference materials"
        case .comics: return "Western comics and graphic novels"
        case .games: return "Video games and board games"
        }
    }
    
    var iconName: String {
        switch self {
        case .manga: return "book.closed"
        case .books: return "books.vertical"
        case .comics: return "magazine"
        case .games: return "gamecontroller"
        }
    }
    
    var color: Color {
        switch self {
        case .manga: return .blue
        case .books: return .green
        case .comics: return .red
        case .games: return .purple
        }
    }
    
    var isLiterature: Bool {
        switch self {
        case .books, .manga, .comics:
            return true
        case .games:
            return false
        }
    }
} 