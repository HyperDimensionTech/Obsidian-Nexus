import SwiftUI

enum ItemCondition: String, CaseIterable, Codable {
    case new = "New"
    case likeNew = "Like New"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    
    var description: String {
        switch self {
        case .new: return "Never used, original packaging"
        case .likeNew: return "Used but looks new"
        case .good: return "Light wear, fully functional"
        case .fair: return "Moderate wear, still usable"
        case .poor: return "Heavy wear, may need repair"
        }
    }
    
    var color: Color {
        switch self {
        case .new: return .green
        case .likeNew: return .blue
        case .good: return .yellow
        case .fair: return .orange
        case .poor: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .new: return "star.fill"
        case .likeNew: return "star.leadinghalf.filled"
        case .good: return "star"
        case .fair: return "exclamationmark.triangle"
        case .poor: return "xmark.circle"
        }
    }
} 