enum ItemCategory: String, CaseIterable, Identifiable {
    case literature = "Books/Manga/Comics"
    case general = "General Items"
    
    var id: String { rawValue }
    
    var types: [CollectionType] {
        switch self {
        case .literature:
            return [.books, .manga, .comics]
        case .general:
            return [.games]
        }
    }
} 