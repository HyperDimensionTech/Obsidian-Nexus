import Foundation

struct Series: Identifiable, Codable {
    let id: UUID
    var name: String
    var type: CollectionType
    var totalVolumes: Int?
    var status: SeriesStatus
    
    enum SeriesStatus: String, CaseIterable, Codable {
        case ongoing
        case completed
        case hiatus
        case cancelled
        
        var description: String {
            switch self {
            case .ongoing: return "Currently releasing"
            case .completed: return "Series finished"
            case .hiatus: return "Temporarily paused"
            case .cancelled: return "Discontinued"
            }
        }
    }
} 