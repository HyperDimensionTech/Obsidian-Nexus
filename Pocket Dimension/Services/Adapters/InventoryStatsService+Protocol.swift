import Foundation

extension InventoryStatsService: CollectionStatsProviding {
    func seriesValueCount(name: String, in items: [InventoryItem]) -> (value: Price, count: Int) {
        let stats = seriesStats(name: name, in: items)
        return (stats.value, stats.count)
    }

    func statsTuple(for items: [InventoryItem]) -> (totalValue: Price, averagePrice: Price, highestPrice: Price, lowestPrice: Price, medianPrice: Price) {
        let s = calculatePriceStats(for: items)
        return (s.totalValue, s.averagePrice, s.highestPrice, s.lowestPrice, s.medianPrice)
    }

    func authorValueCount(name: String, in items: [InventoryItem]) -> (value: Price, count: Int) {
        let s = authorStats(name: name, in: items)
        return (s.value, s.count)
    }
}


