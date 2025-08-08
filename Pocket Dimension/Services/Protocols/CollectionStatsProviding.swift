import Foundation

@MainActor
public protocol CollectionStatsProviding {
    func hasItemsInLocation(_ locationId: UUID, in items: [InventoryItem]) -> Bool
    func totalValue(for type: CollectionType?, in items: [InventoryItem]) -> Price
    func seriesValue(series: String, in items: [InventoryItem]) -> Price
    func seriesValueCount(name: String, in items: [InventoryItem]) -> (value: Price, count: Int)
    func authorValueCount(name: String, in items: [InventoryItem]) -> (value: Price, count: Int)
    func priceRange(for items: [InventoryItem]) -> (min: Price, max: Price)?
    func pricePercentile(_ percentile: Double, for items: [InventoryItem]) -> Price?
    func collectionValue(for type: CollectionType, in items: [InventoryItem]) -> Price
    // Convenience tuple-return version for UI use
    func statsTuple(for items: [InventoryItem]) -> (totalValue: Price, averagePrice: Price, highestPrice: Price, lowestPrice: Price, medianPrice: Price)
}


