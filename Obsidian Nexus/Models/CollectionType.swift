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
    
    /// Indicates whether this collection type is ready for production use
    var isReady: Bool {
        switch self {
        case .books, .manga, .comics:
            return true
        case .games, .collectibles, .electronics, .tools:
            return false
        }
    }
}

extension CollectionType {
    static var literatureTypes: [CollectionType] {
        [.books, .manga, .comics]
    }
    
    /// Collection types that are ready for production use
    static var readyTypes: [CollectionType] {
        allCases.filter { $0.isReady }
    }
    
    /// Determines how items of this collection type should be grouped into series
    var seriesGroupingKey: KeyPath<InventoryItem, String?> {
        switch self {
        case .books, .manga, .comics:
            return \.series
        case .games:
            return \.franchise  // Group games by franchise (e.g., "Final Fantasy", "Mario")
        case .collectibles:
            return \.franchise  // Group collectibles by franchise (e.g., "Marvel", "Pokemon")
        case .electronics:
            return \.series     // Group electronics by product series (e.g., "iPhone", "Galaxy")
        case .tools:
            return \.series     // Group tools by tool series (e.g., "DeWalt 20V", "Milwaukee M18")
        }
    }
    
    /// Alternative grouping key for author-based grouping (primarily for books)
    var authorGroupingKey: KeyPath<InventoryItem, String?> {
        switch self {
        case .books, .manga, .comics:
            return \.author
        case .games:
            return \.developer  // Group games by developer
        case .collectibles:
            return \.manufacturer  // Group collectibles by manufacturer
        case .electronics:
            return \.manufacturer  // Group electronics by manufacturer
        case .tools:
            return \.manufacturer  // Group tools by manufacturer
        }
    }
    
    /// Whether this collection type supports series grouping
    var supportsSeriesGrouping: Bool {
        switch self {
        case .books, .manga, .comics, .games, .collectibles, .electronics, .tools:
            return true
        }
    }
    
    /// Whether this collection type supports author/creator grouping
    var supportsAuthorGrouping: Bool {
        switch self {
        case .books, .manga, .comics, .games, .collectibles, .electronics, .tools:
            return true
        }
    }
    
    /// Appropriate terminology for series items
    var seriesItemTerminology: String {
        switch self {
        case .books, .manga, .comics:
            return "volumes"
        case .games:
            return "games"
        case .collectibles:
            return "items"
        case .electronics:
            return "devices"
        case .tools:
            return "tools"
        }
    }
    
    /// Appropriate terminology for author/creator grouping
    var authorGroupingTerminology: String {
        switch self {
        case .books, .manga, .comics:
            return "books"
        case .games:
            return "games"
        case .collectibles:
            return "items"
        case .electronics:
            return "devices"  
        case .tools:
            return "tools"
        }
    }
} 