import Foundation

enum InventoryError: LocalizedError {
    case invalidTitle
    case invalidLocation
    case saveFailed
    case loadFailed
    case invalidOperation(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidTitle:
            return "Item title cannot be empty"
        case .invalidLocation:
            return "Invalid location selected"
        case .saveFailed:
            return "Failed to save inventory data"
        case .loadFailed:
            return "Failed to load inventory data"
        case .invalidOperation(let reason):
            return reason
        }
    }
} 