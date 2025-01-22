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
        case .books: return "book"
        case .manga: return "book.closed"
        case .comics: return "magazine"
        case .games: return "gamecontroller"
        case .collectibles: return "star"
        case .electronics: return "laptopcomputer"
        case .tools: return "wrench.and.screwdriver"
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
        case .manga: return .blue
        case .books: return .green
        case .comics: return .red
        case .games: return .purple
        case .collectibles: return .yellow
        case .electronics: return .orange
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