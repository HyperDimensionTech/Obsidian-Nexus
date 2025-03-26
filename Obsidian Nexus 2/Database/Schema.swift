struct MediaTypeRule: Codable {
    let id: Int
    let pattern: String
    let patternType: PatternType
    let priority: Int
    let mediaType: CollectionType
    
    enum PatternType: String, Codable {
        case publisher
        case title
        case description
    }
} 