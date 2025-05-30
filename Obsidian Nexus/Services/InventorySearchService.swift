import Foundation

/// Service responsible for searching and filtering inventory items
@MainActor
class InventorySearchService {
    
    // MARK: - Search Options
    struct SearchOptions {
        let includeTitle: Bool
        let includeAuthor: Bool
        let includeSeries: Bool
        let includePublisher: Bool
        let includeISBN: Bool
        let includeDescription: Bool
        let caseSensitive: Bool
        let exactMatch: Bool
        
        static let `default` = SearchOptions(
            includeTitle: true,
            includeAuthor: true,
            includeSeries: true,
            includePublisher: false,
            includeISBN: false,
            includeDescription: false,
            caseSensitive: false,
            exactMatch: false
        )
    }
    
    // MARK: - Search Methods
    
    /// Searches items with default options (maintains existing behavior)
    func searchItems(query: String, in items: [InventoryItem]) -> [InventoryItem] {
        return searchItems(query: query, in: items, options: .default)
    }
    
    /// Advanced search with customizable options
    func searchItems(query: String, in items: [InventoryItem], options: SearchOptions) -> [InventoryItem] {
        guard !query.isEmpty else { return items }
        
        let searchTerms = options.caseSensitive ? 
            query.split(separator: " ").map(String.init) :
            query.lowercased().split(separator: " ").map(String.init)
        
        return items.filter { item in
            if options.exactMatch {
                return exactMatchesAny(item: item, terms: searchTerms, options: options)
            } else {
                return searchTerms.allSatisfy { term in
                    matchesAnyField(item: item, term: term, options: options)
                }
            }
        }
    }
    
    // MARK: - Collection-Specific Searches
    
    /// Get manga series grouped and sorted
    func mangaSeries(from items: [InventoryItem]) -> [(String, [InventoryItem])] {
        let mangaItems = items.filter { $0.type == .manga }
        let grouped = Dictionary(grouping: mangaItems) { $0.series ?? "Unknown Series" }
        
        return grouped.map { (series, items) in
            let sortedItems = items.sorted { 
                ($0.volume ?? 0) < ($1.volume ?? 0)
            }
            return (series, sortedItems)
        }.sorted { $0.0 < $1.0 }
    }
    
    /// Get books grouped by author
    func booksByAuthor(from items: [InventoryItem]) -> [(String, [InventoryItem])] {
        let bookItems = items.filter { $0.type == .books }
        let grouped = Dictionary(grouping: bookItems) { cleanupAuthorName($0.author) }
        
        return grouped.map { (author, items) in
            let sortedItems = items.sorted { $0.title < $1.title }
            return (author, sortedItems)
        }.sorted { $0.0 < $1.0 }
    }
    
    /// Get items by series name
    func itemsInSeries(_ series: String, from items: [InventoryItem]) -> [InventoryItem] {
        return items
            .filter { $0.series?.lowercased() == series.lowercased() }
            .sorted { ($0.volume ?? 0) < ($1.volume ?? 0) }
    }
    
    /// Get items by author
    func itemsByAuthor(_ author: String, from items: [InventoryItem]) -> [InventoryItem] {
        return items
            .filter { cleanupAuthorName($0.author).lowercased() == author.lowercased() }
            .sorted { $0.title < $1.title }
    }
    
    // MARK: - Filtering Methods
    
    /// Filter items by collection type
    func items(for type: CollectionType, from items: [InventoryItem]) -> [InventoryItem] {
        return items.filter { $0.type == type }
    }
    
    /// Filter items by price range
    func itemsWithPriceGreaterThan(_ price: Price, from items: [InventoryItem]) -> [InventoryItem] {
        return items.filter { 
            guard let itemPrice = $0.price else { return false }
            return itemPrice.convertedTo(price.currency).amount > price.amount
        }
    }
    
    func itemsWithPriceLessThan(_ price: Price, from items: [InventoryItem]) -> [InventoryItem] {
        return items.filter { 
            guard let itemPrice = $0.price else { return false }
            return itemPrice.convertedTo(price.currency).amount < price.amount
        }
    }
    
    func itemsWithPriceBetween(_ min: Price, and max: Price, from items: [InventoryItem]) -> [InventoryItem] {
        let currency = min.currency
        return items.filter { 
            guard let itemPrice = $0.price else { return false }
            let convertedPrice = itemPrice.convertedTo(currency).amount
            return convertedPrice >= min.amount && convertedPrice <= max.amount
        }
    }
    
    func itemsWithPriceEqualTo(_ price: Price, from items: [InventoryItem]) -> [InventoryItem] {
        return items.filter { 
            guard let itemPrice = $0.price else { return false }
            return itemPrice.convertedTo(price.currency).amount == price.amount
        }
    }
    
    /// Filter items above average price
    func itemsWithPriceAboveAverage(from items: [InventoryItem], averagePrice: Price) -> [InventoryItem] {
        return items.filter { 
            guard let itemPrice = $0.price else { return false }
            return itemPrice.convertedTo(averagePrice.currency).amount > averagePrice.amount
        }
    }
    
    // MARK: - Sorting Methods
    
    /// Sort items by price
    func sortedByPrice(_ items: [InventoryItem], ascending: Bool = true) -> [InventoryItem] {
        return items.sorted { first, second in
            let firstPrice = first.price?.amount ?? 0
            let secondPrice = second.price?.amount ?? 0
            return ascending ? firstPrice < secondPrice : firstPrice > secondPrice
        }
    }
    
    /// Sort items by title
    func sortedByTitle(_ items: [InventoryItem], ascending: Bool = true) -> [InventoryItem] {
        return items.sorted { first, second in
            return ascending ? first.title < second.title : first.title > second.title
        }
    }
    
    /// Sort items by author
    func sortedByAuthor(_ items: [InventoryItem], ascending: Bool = true) -> [InventoryItem] {
        return items.sorted { first, second in
            let firstAuthor = cleanupAuthorName(first.author)
            let secondAuthor = cleanupAuthorName(second.author)
            return ascending ? firstAuthor < secondAuthor : firstAuthor > secondAuthor
        }
    }
    
    // MARK: - Helper Methods
    
    private func matchesAnyField(item: InventoryItem, term: String, options: SearchOptions) -> Bool {
        let searchTerm = options.caseSensitive ? term : term.lowercased()
        
        // Title match (with normalization for articles)
        if options.includeTitle {
            let title = options.caseSensitive ? item.title : item.title.lowercased()
            let normalizedTitle = title
                .replacingOccurrences(of: "the ", with: "")
                .replacingOccurrences(of: "a ", with: "")
                .replacingOccurrences(of: "an ", with: "")
            
            if normalizedTitle.contains(searchTerm) {
                return true
            }
        }
        
        // Author match
        if options.includeAuthor,
           let author = item.author {
            let searchAuthor = options.caseSensitive ? author : author.lowercased()
            if searchAuthor.contains(searchTerm) {
                return true
            }
        }
        
        // Series match
        if options.includeSeries,
           let series = item.series {
            let searchSeries = options.caseSensitive ? series : series.lowercased()
            if searchSeries.contains(searchTerm) {
                return true
            }
        }
        
        // Publisher match
        if options.includePublisher,
           let publisher = item.publisher {
            let searchPublisher = options.caseSensitive ? publisher : publisher.lowercased()
            if searchPublisher.contains(searchTerm) {
                return true
            }
        }
        
        // ISBN match
        if options.includeISBN,
           let isbn = item.isbn {
            if isbn.contains(searchTerm) {
                return true
            }
        }
        
        // Description match
        if options.includeDescription,
           let synopsis = item.synopsis {
            let searchSynopsis = options.caseSensitive ? synopsis : synopsis.lowercased()
            if searchSynopsis.contains(searchTerm) {
                return true
            }
        }
        
        return false
    }
    
    private func exactMatchesAny(item: InventoryItem, terms: [String], options: SearchOptions) -> Bool {
        return terms.contains { term in
            let searchTerm = options.caseSensitive ? term : term.lowercased()
            
            if options.includeTitle {
                let title = options.caseSensitive ? item.title : item.title.lowercased()
                if title == searchTerm { return true }
            }
            
            if options.includeAuthor,
               let author = item.author {
                let searchAuthor = options.caseSensitive ? author : author.lowercased()
                if searchAuthor == searchTerm { return true }
            }
            
            if options.includeSeries,
               let series = item.series {
                let searchSeries = options.caseSensitive ? series : series.lowercased()
                if searchSeries == searchTerm { return true }
            }
            
            if options.includePublisher,
               let publisher = item.publisher {
                let searchPublisher = options.caseSensitive ? publisher : publisher.lowercased()
                if searchPublisher == searchTerm { return true }
            }
            
            if options.includeISBN,
               let isbn = item.isbn,
               isbn == searchTerm { return true }
            
            return false
        }
    }
    
    private func cleanupAuthorName(_ name: String?) -> String {
        guard let name = name else { return "Unknown Author" }
        
        // Remove common prefixes and normalize
        return name
            .replacingOccurrences(of: "Dr. ", with: "")
            .replacingOccurrences(of: "Mr. ", with: "")
            .replacingOccurrences(of: "Ms. ", with: "")
            .replacingOccurrences(of: "Mrs. ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
} 