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
        let includeBarcode: Bool
        let includeDescription: Bool
        let caseSensitive: Bool
        let exactMatch: Bool
        
        static let `default` = SearchOptions(
            includeTitle: true,
            includeAuthor: true,
            includeSeries: true,
            includePublisher: true,
            includeISBN: true,
            includeBarcode: true,
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
        
        // For exact match, use the original filtering approach but still score results
        if options.exactMatch {
            let exactMatches = items.filter { item in
                return exactMatchesAny(item: item, terms: searchTerms, options: options)
            }
            
            // Score exact matches for better ordering
            let scoredItems = exactMatches.compactMap { item -> (item: InventoryItem, score: Double)? in
                let score = calculateRelevanceScore(item: item, searchTerms: searchTerms, options: options)
                return (item, score)
            }
            
            return scoredItems
                .sorted { $0.score > $1.score }
                .map { $0.item }
        }
        
        // Calculate relevance scores for all items
        let scoredItems = items.compactMap { item -> (item: InventoryItem, score: Double)? in
            let score = calculateRelevanceScore(item: item, searchTerms: searchTerms, options: options)
            return score > 0 ? (item, score) : nil
        }
        
        // Sort by relevance score (highest first) and return items
        return scoredItems
            .sorted { $0.score > $1.score }
            .map { $0.item }
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
        
        // Barcode match
        if options.includeBarcode,
           let barcode = item.barcode {
            if barcode.contains(searchTerm) {
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
               let isbn = item.isbn {
                if isbn.contains(searchTerm) {
                    return true
                }
            }
            
            if options.includeBarcode,
               let barcode = item.barcode {
                if barcode.contains(searchTerm) {
                    return true
                }
            }
            
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
    
    // MARK: - Relevance Scoring
    
    /// Calculate relevance score for an item based on search terms
    private func calculateRelevanceScore(item: InventoryItem, searchTerms: [String], options: SearchOptions) -> Double {
        var totalScore: Double = 0
        let maxPossibleScore = Double(searchTerms.count) * 100 // Each term can contribute up to 100 points
        
        // Calculate individual term scores
        for term in searchTerms {
            let termScore = calculateTermScore(item: item, term: term, options: options)
            totalScore += termScore
        }
        
        // Bonus for multiple terms appearing together
        if searchTerms.count > 1 {
            let combinedQuery = searchTerms.joined(separator: " ").lowercased()
            totalScore += calculatePhraseBonus(item: item, phrase: combinedQuery, options: options)
        }
        
        // Special bonus for exact series matches (helps with "One Piece" type searches)
        if searchTerms.count > 1, let series = item.series {
            let searchPhrase = searchTerms.joined(separator: " ").lowercased()
            let itemSeries = series.lowercased()
            
            if itemSeries == searchPhrase {
                totalScore += 50 // Significant bonus for exact series match
            } else if itemSeries.hasPrefix(searchPhrase) {
                totalScore += 30 // Good bonus for series starting with search phrase
            }
        }
        
        // Normalize score to 0-1 range
        return min(totalScore / maxPossibleScore, 1.0)
    }
    
    /// Calculate bonus score for phrase matches
    private func calculatePhraseBonus(item: InventoryItem, phrase: String, options: SearchOptions) -> Double {
        var bonus: Double = 0
        
        // Title phrase bonus
        if options.includeTitle {
            let title = item.title.lowercased()
            let normalizedTitle = title
                .replacingOccurrences(of: "the ", with: "")
                .replacingOccurrences(of: "a ", with: "")
                .replacingOccurrences(of: "an ", with: "")
            
            if normalizedTitle.contains(phrase) {
                // Exact phrase match gets big bonus
                if normalizedTitle == phrase {
                    bonus += 40
                } else if normalizedTitle.hasPrefix(phrase) {
                    bonus += 30
                } else {
                    bonus += 20
                }
            }
        }
        
        // Series phrase bonus
        if options.includeSeries, let series = item.series {
            let searchSeries = series.lowercased()
            if searchSeries.contains(phrase) {
                if searchSeries == phrase {
                    bonus += 35
                } else if searchSeries.hasPrefix(phrase) {
                    bonus += 25
                } else {
                    bonus += 15
                }
            }
        }
        
        // Author phrase bonus
        if options.includeAuthor, let author = item.author {
            let searchAuthor = author.lowercased()
            if searchAuthor.contains(phrase) {
                bonus += 10
            }
        }
        
        return bonus
    }
    
    /// Calculate score for a single search term against an item
    private func calculateTermScore(item: InventoryItem, term: String, options: SearchOptions) -> Double {
        let searchTerm = options.caseSensitive ? term : term.lowercased()
        var score: Double = 0
        
        // Title scoring (highest weight)
        if options.includeTitle {
            let title = options.caseSensitive ? item.title : item.title.lowercased()
            let normalizedTitle = title
                .replacingOccurrences(of: "the ", with: "")
                .replacingOccurrences(of: "a ", with: "")
                .replacingOccurrences(of: "an ", with: "")
            
            // Exact title match (very high score)
            if normalizedTitle == searchTerm {
                score += 100
            }
            // Title starts with search term (high score)
            else if normalizedTitle.hasPrefix(searchTerm) {
                score += 80
            }
            // Title contains search term (medium score)
            else if normalizedTitle.contains(searchTerm) {
                // Score based on how much of the title matches
                let matchRatio = Double(searchTerm.count) / Double(normalizedTitle.count)
                score += 60 * matchRatio
            }
        }
        
        // Series scoring (high weight for manga/comics)
        if options.includeSeries, let series = item.series {
            let searchSeries = options.caseSensitive ? series : series.lowercased()
            
            // Exact series match
            if searchSeries == searchTerm {
                score += 90
            }
            // Series starts with search term
            else if searchSeries.hasPrefix(searchTerm) {
                score += 70
            }
            // Series contains search term
            else if searchSeries.contains(searchTerm) {
                let matchRatio = Double(searchTerm.count) / Double(searchSeries.count)
                score += 50 * matchRatio
            }
        }
        
        // Author scoring (medium weight)
        if options.includeAuthor, let author = item.author {
            let searchAuthor = options.caseSensitive ? author : author.lowercased()
            
            // Exact author match
            if searchAuthor == searchTerm {
                score += 60
            }
            // Author starts with search term
            else if searchAuthor.hasPrefix(searchTerm) {
                score += 40
            }
            // Author contains search term
            else if searchAuthor.contains(searchTerm) {
                score += 30
            }
        }
        
        // Publisher scoring (lower weight)
        if options.includePublisher, let publisher = item.publisher {
            let searchPublisher = options.caseSensitive ? publisher : publisher.lowercased()
            if searchPublisher.contains(searchTerm) {
                score += 20
            }
        }
        
        // ISBN/Barcode scoring (exact matches get high score)
        if options.includeISBN, let isbn = item.isbn {
            if isbn.contains(searchTerm) {
                // Exact ISBN match gets very high score
                if isbn == searchTerm {
                    score += 95
                } else {
                    score += 50
                }
            }
        }
        
        if options.includeBarcode, let barcode = item.barcode {
            if barcode.contains(searchTerm) {
                // Exact barcode match gets very high score
                if barcode == searchTerm {
                    score += 95
                } else {
                    score += 50
                }
            }
        }
        
        // Description scoring (lowest weight)
        if options.includeDescription, let synopsis = item.synopsis {
            let searchSynopsis = options.caseSensitive ? synopsis : synopsis.lowercased()
            if searchSynopsis.contains(searchTerm) {
                score += 10
            }
        }
        
        return score
    }
} 