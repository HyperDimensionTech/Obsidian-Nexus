enum PublisherType {
    case manga
    case comics
    case books
    case games
    case collectibles
    case electronics
    case tools
    
    var publishers: [String] {
        switch self {
        case .manga:
            return [
                "viz",
                "kodansha",
                "shogakukan", 
                "shueisha",
                "square enix",
                "seven seas",
                "yen press",
                "dark horse manga",
                "vertical comics"
            ]
        case .comics:
            return [
                "marvel",
                "dc comics",
                "image comics",
                "dark horse comics",
                "boom! studios",
                "idw publishing",
                "valiant",
                "dynamite",
                "oni press",
                "fantagraphics",
                "vertigo",
                "aftershock"
            ]
        case .games:
            return [
                "nintendo",
                "sony",
                "microsoft",
                "sega",
                "atlus",
                "square enix games"
            ]
        case .books, .collectibles, .electronics, .tools:
            return []
        }
    }
    
    var searchKeywords: [String] {
        switch self {
        case .manga:
            return ["manga", "vol.", "volume", "tankōbon"]
        case .comics:
            return [
                "comic", 
                "graphic novel",
                "tpb",
                "trade paperback",
                "omnibus",
                "annual",
                "one-shot",
                "superhero",
                "issue #"
            ]
        case .games:
            return ["game", "video game", "nintendo switch", "playstation", "xbox"]
        case .books:
            return ["novel", "book", "textbook", "biography"]
        case .collectibles:
            return ["collectible", "figure", "statue", "model"]
        case .electronics:
            return ["electronic", "computer", "phone", "tablet"]
        case .tools:
            return ["tool", "equipment", "hardware"]
        }
    }
    
    var collectionType: CollectionType {
        switch self {
        case .manga: return .manga
        case .comics: return .comics
        case .books: return .books
        case .games: return .games
        case .collectibles: return .collectibles
        case .electronics: return .electronics
        case .tools: return .tools
        }
    }
} 