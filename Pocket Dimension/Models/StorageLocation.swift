import Foundation

public struct StorageLocation: Identifiable, Codable {
    public let id: UUID
    public var name: String
    public var type: LocationType
    public var parentId: UUID?
    
    private(set) var childIds: Set<UUID>
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case parentId
        case childIds
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(LocationType.self, forKey: .type)
        parentId = try container.decodeIfPresent(UUID.self, forKey: .parentId)
        childIds = try container.decode(Set<UUID>.self, forKey: .childIds)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(parentId, forKey: .parentId)
        try container.encode(childIds, forKey: .childIds)
    }
    
    public enum LocationType: String, CaseIterable, Identifiable, Codable {
        // Rooms
        case room
        case office
        case library
        case storageRoom
        case closet
        case garage
        
        // Furniture
        case bookshelf
        case cabinet
        case desk
        case displayCase
        case entertainmentCenter
        case dresser
        
        // Containers
        case box
        case bin
        case drawer
        case folder
        case shelf
        
        public var id: String { rawValue }
        
        var name: String {
            switch self {
            case .entertainmentCenter: return "Entertainment Center"
            case .displayCase: return "Display Case"
            case .storageRoom: return "Storage Room"
            default:
                return rawValue.capitalized
            }
        }
        
        var icon: String {
            switch self {
            // Rooms
            case .room: return "house"
            case .office: return "briefcase"
            case .library: return "building.columns"
            case .storageRoom: return "archivebox"
            case .closet: return "door.left.hand.closed"
            case .garage: return "car"
            
            // Furniture
            case .bookshelf: return "books.vertical"
            case .cabinet: return "cabinet"
            case .desk: return "desktopcomputer"
            case .displayCase: return "sparkles.rectangle.stack"
            case .entertainmentCenter: return "tv"
            case .dresser: return "square.stack.3d.up"
            
            // Containers
            case .box: return "shippingbox"
            case .bin: return "tray"
            case .drawer: return "tray.2"
            case .folder: return "folder"
            case .shelf: return "square.split.2x1"
            }
        }
        
        var canHaveChildren: Bool {
            switch category {
            case .room, .furniture:
                return true
            case .container:
                // Only allow folders in containers
                return allowedChildTypes.contains(.folder)
            }
        }
        
        var category: LocationCategory {
            switch self {
            case .room, .office, .library, .storageRoom, .closet, .garage:
                return .room
            case .bookshelf, .cabinet, .desk, .displayCase, .entertainmentCenter, .dresser:
                return .furniture
            case .box, .bin, .drawer, .folder, .shelf:
                return .container
            }
        }
        
        var allowedChildTypes: [LocationType] {
            switch category {
            case .room:
                // Rooms can contain both furniture and containers
                return LocationType.allCases.filter { $0.category == .furniture || $0.category == .container }
            case .furniture:
                // Furniture can only contain containers
                return LocationType.allCases.filter { $0.category == .container }
            case .container:
                // Containers can only contain folders
                return [.folder]
            }
        }
        
        var canContainItems: Bool {
            switch category {
            case .room:
                return true  // Allow rooms to contain items (like furniture)
            case .furniture, .container:
                return true  // Furniture and containers can hold items
            }
        }
    }
    
    public enum LocationCategory: String {
        case room = "Rooms"
        case furniture = "Furniture"
        case container = "Containers"
    }
    
    public init(
        id: UUID = UUID(),
        name: String,
        type: LocationType,
        parentId: UUID? = nil,
        childIds: Set<UUID> = []
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.parentId = parentId
        self.childIds = childIds
    }
    
    // MARK: - Child Management
    
    mutating func addChild(_ childId: UUID) -> Bool {
        guard type.canHaveChildren else { return false }
        childIds.insert(childId)
        return true
    }
    
    mutating func removeChild(_ childId: UUID) {
        childIds.remove(childId)
    }
    
    // MARK: - Validation
    
    func canAdd(childType: LocationType) -> Bool {
        type.allowedChildTypes.contains(childType)
    }
}

// MARK: - Equatable & Hashable
extension StorageLocation: Equatable, Hashable {
    public static func == (lhs: StorageLocation, rhs: StorageLocation) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
} 