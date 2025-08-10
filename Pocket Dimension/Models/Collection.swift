import Foundation

struct Collection: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String?
    var dateCreated: Date
    var type: CollectionType
    var itemIds: [UUID] = []
    
    init(id: UUID = UUID(), 
         name: String, 
         description: String? = nil, 
         type: CollectionType,
         dateCreated: Date = Date()) {
        self.id = id
        self.name = name
        self.description = description
        self.type = type
        self.dateCreated = dateCreated
    }
} 