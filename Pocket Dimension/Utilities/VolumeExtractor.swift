import Foundation

/// Utility for extracting volume numbers from titles and providing volume-aware sorting
struct VolumeExtractor {
    
    /// Extract volume number from a title string
    /// Handles formats like: "Vol. 10", "Volume 5", "Vol 3", "#15", "One Piece, Vol. 100"
    static func extractVolumeNumber(from title: String) -> Int? {
        // Common volume patterns
        let patterns = [
            #"(?i)vol\.?\s*(\d+)"#,           // "Vol. 10", "vol 5", "VOL.3"
            #"(?i)volume\s*(\d+)"#,           // "Volume 10", "volume 5"
            #"(?i)#(\d+)"#,                   // "#10", "#5"
            #",\s*(\d+)$"#,                   // "Title, 10" (ending with number)
            #"\s+(\d+)$"#                     // "Title 10" (ending with space + number)
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: title, options: [], range: NSRange(title.startIndex..., in: title)),
               let range = Range(match.range(at: 1), in: title) {
                let numberString = String(title[range])
                if let number = Int(numberString) {
                    return number
                }
            }
        }
        
        return nil
    }
    
    /// Extract series name from a title by removing volume information
    /// "One Piece, Vol. 10" → "One Piece"
    /// "Chainsaw Man, Vol. 5" → "Chainsaw Man"
    static func extractSeriesName(from title: String) -> String {
        let patterns = [
            #"(?i),\s*vol\.?\s*\d+"#,         // ", Vol. 10", ", vol 5"
            #"(?i),\s*volume\s*\d+"#,         // ", Volume 10"
            #"(?i)\s*#\d+"#,                  // " #10"
            #"(?i)\s*vol\.?\s*\d+"#,          // " Vol. 10", " vol 5"
            #"(?i)\s*volume\s*\d+"#,          // " Volume 10"
            #",\s*\d+$"#,                     // ", 10" (ending)
            #"\s+\d+$"#                       // " 10" (ending)
        ]
        
        var seriesName = title
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                seriesName = regex.stringByReplacingMatches(
                    in: seriesName,
                    options: [],
                    range: NSRange(seriesName.startIndex..., in: seriesName),
                    withTemplate: ""
                )
            }
        }
        
        return seriesName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Fuzzy match function for flexible search
    /// Handles cases like: "One Piece Vol 1" -> "One Piece, Vol. 1"
    /// "chainsaw man 5" -> "Chainsaw Man, Vol. 5"
    static func fuzzyMatches(searchQuery: String, against text: String) -> Bool {
        let normalizedQuery = normalizeSearchText(searchQuery)
        let normalizedText = normalizeSearchText(text)
        
        // Direct substring match (fastest check)
        if normalizedText.contains(normalizedQuery) {
            return true
        }
        
        // Split query into words for flexible matching
        let queryWords = normalizedQuery.split(separator: " ").map(String.init)
        let textWords = normalizedText.split(separator: " ").map(String.init)
        
        // Check if all query words exist in text (in any order)
        let allWordsMatch = queryWords.allSatisfy { queryWord in
            textWords.contains { textWord in
                textWord.contains(queryWord) || queryWord.contains(textWord)
            }
        }
        
        if allWordsMatch {
            return true
        }
        
        // Handle volume-specific patterns
        return matchesVolumePattern(query: normalizedQuery, text: normalizedText)
    }
    
    /// Normalize text for fuzzy matching (remove punctuation, lowercase, etc)
    private static func normalizeSearchText(_ text: String) -> String {
        return text
            .lowercased()
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Match volume-specific patterns like "title vol 5" against "Title, Vol. 5"
    private static func matchesVolumePattern(query: String, text: String) -> Bool {
        // Pattern: "series vol number" or "series volume number"
        let volumePatterns = [
            #"(.+?)\s+(vol|volume)\s+(\d+)"#,
            #"(.+?)\s+(\d+)$"#  // "series 5" pattern
        ]
        
        for pattern in volumePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: query, options: [], range: NSRange(query.startIndex..., in: query)) {
                
                // Safe range conversion - avoid crashes
                guard let seriesRange = Range(match.range(at: 1), in: query) else { continue }
                let series = String(query[seriesRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Check if text contains the series name
                if text.contains(series) {
                    // If it's a volume pattern, also check if the volume number matches
                    if match.numberOfRanges >= 4, 
                       let volumeRange = Range(match.range(at: 3), in: query) {
                        let volumeNumber = String(query[volumeRange])
                        return text.contains(volumeNumber)
                    } else if match.numberOfRanges >= 3, 
                              let volumeRange = Range(match.range(at: 2), in: query) {
                        let volumeNumber = String(query[volumeRange])
                        return text.contains(volumeNumber)
                    }
                    return true
                }
            }
        }
        
        return false
    }
    
    /// Sort items with hybrid logic: series name alphabetically, then volume number numerically within each series
    static func sortItemsByVolume<T>(_ items: [T], titleKeyPath: KeyPath<T, String>) -> [T] {
        return items.sorted { item1, item2 in
            let title1 = item1[keyPath: titleKeyPath]
            let title2 = item2[keyPath: titleKeyPath]
            
            let series1 = extractSeriesName(from: title1)
            let series2 = extractSeriesName(from: title2)
            
            // First, compare series names alphabetically
            let seriesComparison = series1.localizedCaseInsensitiveCompare(series2)
            if seriesComparison != .orderedSame {
                return seriesComparison == .orderedAscending
            }
            
            // If same series, sort by volume number
            let vol1 = extractVolumeNumber(from: title1)
            let vol2 = extractVolumeNumber(from: title2)
            
            // If both have volumes, sort numerically
            if let v1 = vol1, let v2 = vol2 {
                return v1 < v2
            }
            
            // If only one has a volume, put the volumed one first
            if vol1 != nil && vol2 == nil {
                return true
            }
            if vol1 == nil && vol2 != nil {
                return false
            }
            
            // Neither has volumes, sort by full title
            return title1.localizedCaseInsensitiveCompare(title2) == .orderedAscending
        }
    }
    
    /// Sort InventoryItems with hybrid series/volume logic
    static func sortInventoryItemsByVolume(_ items: [InventoryItem]) -> [InventoryItem] {
        return sortItemsByVolume(items, titleKeyPath: \.title)
    }
    
    /// Sort GoogleBooks with hybrid series/volume logic  
    static func sortGoogleBooksByVolume(_ books: [GoogleBook]) -> [GoogleBook] {
        return sortItemsByVolume(books, titleKeyPath: \.volumeInfo.title)
    }
} 