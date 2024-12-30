import Foundation

struct StorageLocation: Identifiable, Codable {
    let id: UUID
    var name: String
    var type: LocationType
    var parentId: UUID?
    
    private(set) var childIds: Set<UUID>
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case parentId
        case childIds
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(LocationType.self, forKey: .type)
        parentId = try container.decodeIfPresent(UUID.self, forKey: .parentId)
        childIds = try container.decode(Set<UUID>.self, forKey: .childIds)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(parentId, forKey: .parentId)
        try container.encode(childIds, forKey: .childIds)
    }
    
    enum LocationType: String, CaseIterable, Identifiable, Codable {
        case room
        case shelf
        case cabinet
        case box
        
        var id: String { rawValue }
        
        var name: String {
            rawValue.capitalized
        }
        
        var icon: String {
            switch self {
            case .room: return "house"
            case .shelf: return "books.vertical"
            case .cabinet: return "cabinet"
            case .box: return "shippingbox"
            }
        }
        
        var canHaveChildren: Bool {
            !allowedChildTypes.isEmpty
        }
        
        var allowedChildTypes: [LocationType] {
            switch self {
            case .room:
                return [.shelf, .cabinet, .box]
            case .shelf:
                return [.box]
            case .cabinet:
                return [.box]
            case .box:
                return []
            }
        }
    }
    
    init(
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
    static func == (lhs: StorageLocation, rhs: StorageLocation) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
} 