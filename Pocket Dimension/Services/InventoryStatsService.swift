import Foundation

/// Service responsible for calculating statistics and analytics for inventory items
@MainActor
class InventoryStatsService {
    
    // MARK: - Price Statistics
    
    struct PriceStatistics {
        let totalValue: Price
        let averagePrice: Price
        let highestPrice: Price
        let lowestPrice: Price
        let medianPrice: Price
        let count: Int
    }
    
    /// Calculate comprehensive price statistics for a collection of items
    func calculatePriceStats(for items: [InventoryItem]) -> PriceStatistics {
        let prices = items.compactMap { $0.price?.amount }
        
        guard !prices.isEmpty else {
            return PriceStatistics(
                totalValue: Price(amount: 0),
                averagePrice: Price(amount: 0),
                highestPrice: Price(amount: 0),
                lowestPrice: Price(amount: 0),
                medianPrice: Price(amount: 0),
                count: 0
            )
        }
        
        let sum = prices.reduce(0, +)
        let avg = sum / Decimal(prices.count)
        let max = prices.max() ?? 0
        let min = prices.min() ?? 0
        let sorted = prices.sorted()
        let median = sorted[sorted.count / 2]
        
        return PriceStatistics(
            totalValue: Price(amount: sum),
            averagePrice: Price(amount: avg),
            highestPrice: Price(amount: max),
            lowestPrice: Price(amount: min),
            medianPrice: Price(amount: median),
            count: prices.count
        )
    }
    
    /// Calculate total value for a specific collection type
    func totalValue(for type: CollectionType?, in items: [InventoryItem]) -> Price {
        let filteredItems = type == nil ? items : items.filter { $0.type == type }
        let total = filteredItems.reduce(Decimal(0)) { sum, item in
            sum + (item.price?.amount ?? 0)
        }
        return Price(amount: total)
    }
    
    /// Calculate value for a specific series
    func seriesValue(series: String, in items: [InventoryItem]) -> Price {
        let seriesItems = items.filter { $0.series?.lowercased() == series.lowercased() }
        let total = seriesItems.reduce(Decimal(0)) { sum, item in
            sum + (item.price?.amount ?? 0)
        }
        return Price(amount: total)
    }
    
    /// Calculate value for a collection type
    func collectionValue(for type: CollectionType, in items: [InventoryItem]) -> Price {
        let typeItems = items.filter { $0.type == type }
        let total = typeItems.reduce(Decimal(0)) { sum, item in
            sum + (item.price?.amount ?? 0)
        }
        return Price(amount: total)
    }
    
    // MARK: - Series Statistics
    
    struct SeriesStatistics {
        let value: Price
        let count: Int
        let averageVolumePrice: Price
        let missingVolumes: [Int]
    }
    
    /// Calculate comprehensive statistics for a series
    func seriesStats(name: String, in items: [InventoryItem]) -> SeriesStatistics {
        let seriesItems = items.filter { $0.series?.lowercased() == name.lowercased() }
        let value = seriesValue(series: name, in: items)
        let count = seriesItems.count
        
        // Calculate missing volumes if series has volume information
        let volumes = seriesItems.compactMap { $0.volume }.sorted()
        let missingVolumes = calculateMissingVolumes(volumes)
        
        let averageVolumePrice = count > 0 ? 
            Price(amount: value.amount / Decimal(count)) : 
            Price(amount: 0)
        
        return SeriesStatistics(
            value: value,
            count: count,
            averageVolumePrice: averageVolumePrice,
            missingVolumes: missingVolumes
        )
    }
    
    // MARK: - Author Statistics
    
    struct AuthorStatistics {
        let value: Price
        let count: Int
        let series: [String]
        let averageBookPrice: Price
        let mostExpensiveBook: InventoryItem?
        let leastExpensiveBook: InventoryItem?
    }
    
    /// Calculate comprehensive statistics for an author
    func authorStats(name: String, in items: [InventoryItem]) -> AuthorStatistics {
        let authorItems = items.filter { 
            cleanupAuthorName($0.author).lowercased() == name.lowercased() 
        }
        
        let value = authorItems.reduce(Decimal(0)) { sum, item in
            sum + (item.price?.amount ?? 0)
        }
        
        let series = Set(authorItems.compactMap { $0.series }).sorted()
        let count = authorItems.count
        
        let averagePrice = count > 0 ? 
            Price(amount: value / Decimal(count)) : 
            Price(amount: 0)
        
        let sortedByPrice = authorItems
            .filter { $0.price?.amount ?? 0 > 0 }
            .sorted { ($0.price?.amount ?? 0) < ($1.price?.amount ?? 0) }
        
        return AuthorStatistics(
            value: Price(amount: value),
            count: count,
            series: series,
            averageBookPrice: averagePrice,
            mostExpensiveBook: sortedByPrice.last,
            leastExpensiveBook: sortedByPrice.first
        )
    }
    
    // MARK: - Collection Type Statistics
    
    /// Get item count for a collection type
    func itemCount(for type: CollectionType, in items: [InventoryItem]) -> Int {
        return items.filter { $0.type == type }.count
    }
    
    /// Get item count for a series
    func seriesItemCount(for series: String, in items: [InventoryItem]) -> Int {
        return items.filter { $0.series?.lowercased() == series.lowercased() }.count
    }
    
    /// Get item count for an author
    func authorItemCount(for author: String, in items: [InventoryItem]) -> Int {
        return items.filter { 
            cleanupAuthorName($0.author).lowercased() == author.lowercased() 
        }.count
    }
    
    // MARK: - Price Analysis
    
    /// Get price range for items
    func priceRange(for items: [InventoryItem]) -> (min: Price, max: Price)? {
        let prices = items.compactMap { $0.price?.amount }
        guard !prices.isEmpty,
              let min = prices.min(),
              let max = prices.max() else {
            return nil
        }
        
        return (Price(amount: min), Price(amount: max))
    }
    
    /// Calculate price percentile
    func pricePercentile(_ percentile: Double, for items: [InventoryItem]) -> Price? {
        let prices = items.compactMap { $0.price?.amount }.sorted()
        guard !prices.isEmpty, percentile >= 0, percentile <= 100 else {
            return nil
        }
        
        let index = Int((percentile / 100.0) * Double(prices.count - 1))
        return Price(amount: prices[index])
    }
    
    /// Calculate detailed price statistics
    func priceStatistics(for items: [InventoryItem]) -> (mean: Price, median: Price, mode: Price?)? {
        let prices = items.compactMap { $0.price?.amount }
        guard !prices.isEmpty else { return nil }
        
        let sum = prices.reduce(0, +)
        let mean = sum / Decimal(prices.count)
        
        let sorted = prices.sorted()
        let median = sorted[sorted.count / 2]
        
        // Calculate mode (most frequent price)
        let frequency = Dictionary(grouping: prices, by: { $0 })
        let maxFrequency = frequency.values.map(\.count).max() ?? 0
        let modes = frequency.filter { $0.value.count == maxFrequency }.keys
        let mode = modes.first // Take first if multiple modes exist
        
        return (
            mean: Price(amount: mean),
            median: Price(amount: median),
            mode: mode.map { Price(amount: $0) }
        )
    }
    
    // MARK: - Location Statistics
    
    /// Check if items exist in a specific location
    func hasItemsInLocation(_ locationId: UUID, in items: [InventoryItem]) -> Bool {
        return items.contains { $0.locationId == locationId }
    }
    
    /// Get item count for a location
    func locationItemCount(for locationId: UUID, in items: [InventoryItem]) -> Int {
        return items.filter { $0.locationId == locationId }.count
    }
    
    /// Get total value for a location
    func locationValue(_ locationId: UUID, in items: [InventoryItem]) -> Price {
        let locationItems = items.filter { $0.locationId == locationId }
        let total = locationItems.reduce(Decimal(0)) { sum, item in
            sum + (item.price?.amount ?? 0)
        }
        return Price(amount: total)
    }
    
    // MARK: - Helper Methods
    
    private func calculateMissingVolumes(_ volumes: [Int]) -> [Int] {
        guard !volumes.isEmpty,
              let min = volumes.min(),
              let max = volumes.max() else {
            return []
        }
        
        let expectedVolumes = Set(min...max)
        let actualVolumes = Set(volumes)
        return Array(expectedVolumes.subtracting(actualVolumes)).sorted()
    }
    
    private func cleanupAuthorName(_ name: String?) -> String {
        guard let name = name else { return "Unknown Author" }
        
        return name
            .replacingOccurrences(of: "Dr. ", with: "")
            .replacingOccurrences(of: "Mr. ", with: "")
            .replacingOccurrences(of: "Ms. ", with: "")
            .replacingOccurrences(of: "Mrs. ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
} 