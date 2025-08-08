import Foundation

/// Advanced duplicate detection service for inventory items
@MainActor
class DuplicateDetectionService {
    
    // MARK: - Duplicate Detection Results
    
    struct DuplicateResult {
        let isDuplicate: Bool
        let existingItem: InventoryItem?
        let matchType: MatchType
        let confidence: Double // 0.0 to 1.0
        
        enum MatchType {
            case exactISBN          // Same ISBN
            case titleAuthor        // Same title + author
            case titleAuthorSeries  // Same title + author + series/volume
            case titleSimilar       // Very similar title
            case none
        }
    }
    
    // MARK: - Configuration
    
    private struct DetectionConfig {
        static let titleSimilarityThreshold: Double = 0.85
        static let titleExactMatchThreshold: Double = 0.95
        static let authorSimilarityThreshold: Double = 0.80
    }
    
    // MARK: - Public Methods
    
    /// Comprehensive duplicate detection for new items
    func detectDuplicate(for newItem: InventoryItem, in existingItems: [InventoryItem]) -> DuplicateResult {
        
        // 1. Exact ISBN match (highest confidence)
        if let isbn = newItem.isbn?.cleaned, !isbn.isEmpty {
            if let existing = findByISBN(isbn, in: existingItems) {
                return DuplicateResult(
                    isDuplicate: true,
                    existingItem: existing,
                    matchType: .exactISBN,
                    confidence: 1.0
                )
            }
        }
        
        // 2. Title + Author match (high confidence)
        if let existing = findByTitleAndAuthor(newItem, in: existingItems) {
            return DuplicateResult(
                isDuplicate: true,
                existingItem: existing,
                matchType: .titleAuthor,
                confidence: 0.9
            )
        }
        
        // 3. Title + Author + Series/Volume match (very high confidence)
        if let existing = findByTitleAuthorSeries(newItem, in: existingItems) {
            return DuplicateResult(
                isDuplicate: true,
                existingItem: existing,
                matchType: .titleAuthorSeries,
                confidence: 0.95
            )
        }
        
        // 4. Similar title match (medium confidence)
        if let existing = findBySimilarTitle(newItem, in: existingItems) {
            return DuplicateResult(
                isDuplicate: true,
                existingItem: existing,
                matchType: .titleSimilar,
                confidence: 0.75
            )
        }
        
        return DuplicateResult(
            isDuplicate: false,
            existingItem: nil,
            matchType: .none,
            confidence: 0.0
        )
    }
    
    /// Merge information from new item into existing item
    func mergeItems(existing: InventoryItem, new: InventoryItem) -> InventoryItem {
        return InventoryItem(
            title: existing.title, // Keep existing title
            type: existing.type,
            series: existing.series ?? new.series, // Use new if existing is nil
            volume: existing.volume ?? new.volume,
            condition: existing.condition, // Keep existing condition
            locationId: existing.locationId,
            notes: mergeNotes(existing.notes, new.notes),
            id: existing.id, // Keep existing ID
            dateAdded: existing.dateAdded, // Keep existing date
            barcode: existing.barcode ?? new.barcode, // Add new barcode if missing
            thumbnailURL: existing.thumbnailURL ?? new.thumbnailURL, // Use new if missing
            author: existing.author ?? new.author,
            manufacturer: existing.manufacturer ?? new.manufacturer,
            originalPublishDate: existing.originalPublishDate ?? new.originalPublishDate,
            publisher: existing.publisher ?? new.publisher,
            isbn: mergeISBNs(existing.isbn, new.isbn), // Combine ISBNs
            price: existing.price ?? new.price, // Use new if missing
            purchaseDate: existing.purchaseDate,
            synopsis: existing.synopsis ?? new.synopsis,
            customImageData: existing.customImageData,
            imageSource: existing.imageSource != .none ? existing.imageSource : new.imageSource,
            serialNumber: existing.serialNumber ?? new.serialNumber,
            modelNumber: existing.modelNumber ?? new.modelNumber,
            character: existing.character ?? new.character,
            franchise: existing.franchise ?? new.franchise,
            dimensions: existing.dimensions ?? new.dimensions,
            weight: existing.weight ?? new.weight,
            releaseDate: existing.releaseDate ?? new.releaseDate,
            limitedEditionNumber: existing.limitedEditionNumber ?? new.limitedEditionNumber,
            hasOriginalPackaging: existing.hasOriginalPackaging ?? new.hasOriginalPackaging,
            platform: existing.platform ?? new.platform,
            developer: existing.developer ?? new.developer,
            genre: existing.genre ?? new.genre,
            ageRating: existing.ageRating ?? new.ageRating,
            technicalSpecs: existing.technicalSpecs ?? new.technicalSpecs,
            warrantyExpiry: existing.warrantyExpiry ?? new.warrantyExpiry
        )
    }
    
    // MARK: - Private Detection Methods
    
    private func findByISBN(_ isbn: String, in items: [InventoryItem]) -> InventoryItem? {
        let cleanISBN = isbn.cleaned
        return items.first { item in
            guard let itemISBN = item.isbn?.cleaned else { return false }
            return itemISBN == cleanISBN
        }
    }
    
    private func findByTitleAndAuthor(_ newItem: InventoryItem, in items: [InventoryItem]) -> InventoryItem? {
        let newTitle = newItem.title.normalized
        let newAuthor = newItem.author?.normalized ?? ""
        
        return items.first { item in
            let itemTitle = item.title.normalized
            let itemAuthor = item.author?.normalized ?? ""
            
            // Title must be very similar and author must match
            let titleSimilarity = itemTitle.similarity(to: newTitle)
            let authorSimilarity = itemAuthor.similarity(to: newAuthor)
            
            return titleSimilarity >= DetectionConfig.titleExactMatchThreshold &&
                   authorSimilarity >= DetectionConfig.authorSimilarityThreshold
        }
    }
    
    private func findByTitleAuthorSeries(_ newItem: InventoryItem, in items: [InventoryItem]) -> InventoryItem? {
        guard let newSeries = newItem.series?.normalized,
              let newVolume = newItem.volume else { return nil }
        
        let newTitle = newItem.title.normalized
        let newAuthor = newItem.author?.normalized ?? ""
        
        return items.first { item in
            guard let itemSeries = item.series?.normalized,
                  let itemVolume = item.volume else { return false }
            
            let itemTitle = item.title.normalized
            let itemAuthor = item.author?.normalized ?? ""
            
            // Series, volume, and author must match, title should be similar
            let titleSimilarity = itemTitle.similarity(to: newTitle)
            let authorSimilarity = itemAuthor.similarity(to: newAuthor)
            let seriesSimilarity = itemSeries.similarity(to: newSeries)
            
            return itemVolume == newVolume &&
                   seriesSimilarity >= 0.9 &&
                   authorSimilarity >= DetectionConfig.authorSimilarityThreshold &&
                   titleSimilarity >= 0.7 // Lower threshold for series items
        }
    }
    
    private func findBySimilarTitle(_ newItem: InventoryItem, in items: [InventoryItem]) -> InventoryItem? {
        let newTitle = newItem.title.normalized
        
        return items.first { item in
            let itemTitle = item.title.normalized
            let similarity = itemTitle.similarity(to: newTitle)
            
            return similarity >= DetectionConfig.titleSimilarityThreshold &&
                   newItem.type == item.type // Same collection type
        }
    }
    
    // MARK: - Merge Helper Methods
    
    private func mergeNotes(_ existing: String?, _ new: String?) -> String? {
        switch (existing, new) {
        case (nil, let newNotes):
            return newNotes
        case (let existingNotes, nil):
            return existingNotes
        case (let existingNotes?, let newNotes?):
            // Combine notes if different
            if existingNotes.contains(newNotes) || newNotes.contains(existingNotes) {
                return existingNotes // Don't duplicate
            } else {
                return "\(existingNotes)\n\n[Additional Info]: \(newNotes)"
            }
        }
    }
    
    private func mergeISBNs(_ existing: String?, _ new: String?) -> String? {
        switch (existing, new) {
        case (nil, let newISBN):
            return newISBN
        case (let existingISBN, nil):
            return existingISBN
        case (let existingISBN?, let newISBN?):
            // If different ISBNs, combine them
            if existingISBN.cleaned != newISBN.cleaned {
                return "\(existingISBN) | \(newISBN)"
            } else {
                return existingISBN
            }
        }
    }
}

// MARK: - String Extensions for Duplicate Detection

private extension String {
    /// Clean and normalize string for comparison
    var normalized: String {
        return self
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "the ", with: "")
            .replacingOccurrences(of: "a ", with: "")
            .replacingOccurrences(of: "an ", with: "")
            .replacingOccurrences(of: "vol.", with: "volume")
            .replacingOccurrences(of: "vol ", with: "volume ")
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Clean ISBN/barcode for comparison
    var cleaned: String {
        return self
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "|", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Calculate similarity between two strings (Jaro-Winkler-like algorithm)
    func similarity(to other: String) -> Double {
        let selfChars = Array(self)
        let otherChars = Array(other)
        
        guard !selfChars.isEmpty && !otherChars.isEmpty else { return 0.0 }
        
        if self == other { return 1.0 }
        
        let maxLength = max(selfChars.count, otherChars.count)
        guard maxLength > 0 else { return 0.0 }
        
        let matchWindow = max(0, maxLength / 2 - 1)
        
        var selfMatches = Array(repeating: false, count: selfChars.count)
        var otherMatches = Array(repeating: false, count: otherChars.count)
        
        var matches = 0
        
        // Find matches with safe bounds checking
        for i in 0..<selfChars.count {
            let start = max(0, i - matchWindow)
            let end = min(i + matchWindow + 1, otherChars.count)
            
            // Ensure start <= end
            guard start < end else { continue }
            
            for j in start..<end {
                // Ensure we don't go out of bounds
                guard j < otherMatches.count && j < otherChars.count else { break }
                
                if otherMatches[j] || selfChars[i] != otherChars[j] { continue }
                selfMatches[i] = true
                otherMatches[j] = true
                matches += 1
                break
            }
        }
        
        guard matches > 0 else { return 0.0 }
        
        // Calculate transpositions with safe bounds checking
        var transpositions = 0
        var k = 0
        
        for i in 0..<selfChars.count {
            if !selfMatches[i] { continue }
            
            // Find next match in other string
            while k < otherMatches.count && !otherMatches[k] { 
                k += 1 
            }
            
            // Ensure we haven't gone out of bounds
            guard k < otherChars.count && k < otherMatches.count else { break }
            
            if selfChars[i] != otherChars[k] { transpositions += 1 }
            k += 1
        }
        
        let jaro = (Double(matches) / Double(selfChars.count) +
                    Double(matches) / Double(otherChars.count) +
                    Double(matches - transpositions / 2) / Double(matches)) / 3.0
        
        return jaro
    }
} 