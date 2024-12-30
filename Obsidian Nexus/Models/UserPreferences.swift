import SwiftUI

class UserPreferences: ObservableObject {
    enum Theme: String, CaseIterable {
        case system
        case light
        case dark
        
        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }
    
    enum ViewStyle: String, CaseIterable {
        case grid
        case list
        case compact
        
        var columns: [GridItem] {
            switch self {
            case .grid: return [GridItem(.adaptive(minimum: 160))]
            case .list: return [GridItem(.flexible())]
            case .compact: return [GridItem(.adaptive(minimum: 100))]
            }
        }
    }
    
    @Published var theme: Theme = .system
    @Published var viewStyle: ViewStyle = .grid
    @Published var showCompletionStatus: Bool = true
    @Published var defaultCollection: CollectionType = .books
} 