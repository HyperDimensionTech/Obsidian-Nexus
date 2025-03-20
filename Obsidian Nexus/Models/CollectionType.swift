import SwiftUI

enum CollectionType: String, CaseIterable, Identifiable, Codable {
    case books
    case manga
    case comics
    case games
    case collectibles
    case electronics
    case tools
    
    var id: String { rawValue }
    
    var name: String {
        switch self {
        case .books: return "Books"
        case .manga: return "Manga"
        case .comics: return "Comics"
        case .games: return "Games"
        case .collectibles: return "Collectibles"
        case .electronics: return "Electronics"
        case .tools: return "Tools"
        }
    }
    
    var iconName: String {
        switch self {
        case .books: return "books.vertical.fill"
        case .manga: return "text.book.closed.fill"
        case .comics: return "magazine.fill"
        case .games: return "gamecontroller.fill"
        case .collectibles: return "sparkles.square.fill.on.square"
        case .electronics: return "desktopcomputer"
        case .tools: return "hammer.fill"
        }
    }
    
    var description: String {
        switch self {
        case .manga: return "Japanese comics and graphic novels"
        case .books: return "Novels, textbooks, and reference materials"
        case .comics: return "Western comics and graphic novels"
        case .games: return "Video games and board games"
        case .collectibles: return "Collectibles"
        case .electronics: return "Electronics"
        case .tools: return "Tools"
        }
    }
    
    var color: Color {
        switch self {
        case .manga: return .indigo
        case .books: return .mint
        case .comics: return .pink
        case .games: return .purple
        case .collectibles: return .orange
        case .electronics: return .teal
        case .tools: return .gray
        }
    }
    
    var isLiterature: Bool {
        switch self {
        case .books, .manga, .comics:
            return true
        default:
            return false
        }
    }
}

extension CollectionType {
    static var literatureTypes: [CollectionType] {
        [.books, .manga, .comics]
    }
} 