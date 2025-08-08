import Foundation

@MainActor
public protocol InventoryValidating {
    func validateForDuplicates(_ item: InventoryItem, existingItems: [InventoryItem], isUpdate: Bool) throws
    func duplicateExists(_ item: InventoryItem, existingItems: [InventoryItem]) -> Bool
}


