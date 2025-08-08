import Foundation

@MainActor
public protocol InventorySearching {
    func itemsByAuthor(_ author: String, from items: [InventoryItem]) -> [InventoryItem]
    func itemsWithPriceGreaterThan(_ price: Price, from items: [InventoryItem]) -> [InventoryItem]
    func itemsWithPriceLessThan(_ price: Price, from items: [InventoryItem]) -> [InventoryItem]
    func itemsWithPriceBetween(_ min: Price, and max: Price, from items: [InventoryItem]) -> [InventoryItem]
    func itemsWithPriceEqualTo(_ price: Price, from items: [InventoryItem]) -> [InventoryItem]
    func itemsWithPriceAboveAverage(from items: [InventoryItem], averagePrice: Price) -> [InventoryItem]
    func sortedByPrice(_ items: [InventoryItem], ascending: Bool) -> [InventoryItem]
}


