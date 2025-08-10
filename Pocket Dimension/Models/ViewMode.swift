import Foundation

/**
 Defines the display mode for collection and series views.
 
 Used throughout the app to provide consistent view switching between
 list-based and card-based presentations.
 */
enum ViewMode: String, CaseIterable, Identifiable {
    case list = "list"
    case card = "card"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .list: return "List"
        case .card: return "Card"
        }
    }
    
    var iconName: String {
        switch self {
        case .list: return "list.bullet"
        case .card: return "square.grid.2x2"
        }
    }
} 