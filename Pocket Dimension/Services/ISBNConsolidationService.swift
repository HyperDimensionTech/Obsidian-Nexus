import Foundation

/// Service responsible for consolidating multiple Google Books results into enhanced single records
@MainActor
class ISBNConsolidationService {
    
    // MARK: - Consolidation Result
    
    struct ConsolidatedResult {
        let consolidatedBook: GoogleBook
        let sourceBooks: [GoogleBook]
        let confidence: Double // 0.0 to 1.0, how confident we are in the consolidation
        let allISBNs: [String]
    }
    
    // MARK: - Public Methods
    
    /// Attempts to consolidate multiple Google Books results into a single enhanced result
    /// Returns nil if consolidation is not recommended
    func consolidateResults(_ books: [GoogleBook]) -> ConsolidatedResult? {
        guard books.count > 1 else { return nil }
        
        // Group books by similarity
        let groups = groupSimilarBooks(books)
        
        // Find the largest group (most similar books)
        guard let largestGroup = groups.max(by: { $0.count < $1.count }),
              largestGroup.count > 1 else {
            return nil
        }
        
        // Only consolidate if we're confident (at least 2 very similar books)
        let confidence = calculateConsolidationConfidence(largestGroup)
        guard confidence >= 0.75 else { return nil }
        
        // Create consolidated result
        let consolidatedBook = createConsolidatedBook(from: largestGroup)
        let allISBNs = extractAllISBNs(from: largestGroup)
        
        return ConsolidatedResult(
            consolidatedBook: consolidatedBook,
            sourceBooks: largestGroup,
            confidence: confidence,
            allISBNs: allISBNs
        )
    }
    
    // MARK: - Private Methods
    
    /// Groups books by similarity (title, author, series)
    private func groupSimilarBooks(_ books: [GoogleBook]) -> [[GoogleBook]] {
        var groups: [[GoogleBook]] = []
        var processed: Set<String> = []
        
        for book in books {
            if processed.contains(book.id) { continue }
            
            var similarBooks = [book]
            processed.insert(book.id)
            
            // Find other books similar to this one
            for otherBook in books {
                if otherBook.id != book.id && !processed.contains(otherBook.id) {
                    if areBooksConsolidatable(book, otherBook) {
                        similarBooks.append(otherBook)
                        processed.insert(otherBook.id)
                    }
                }
            }
            
            groups.append(similarBooks)
        }
        
        return groups
    }
    
    /// Determines if two books should be consolidated
    private func areBooksConsolidatable(_ book1: GoogleBook, _ book2: GoogleBook) -> Bool {
        let title1 = normalizeTitle(book1.volumeInfo.title)
        let title2 = normalizeTitle(book2.volumeInfo.title)
        
        // Must have very similar titles
        guard titleSimilarity(title1, title2) >= 0.9 else { return false }
        
        // Must have same author (if available)
        let author1 = book1.volumeInfo.authors?.first?.lowercased() ?? ""
        let author2 = book2.volumeInfo.authors?.first?.lowercased() ?? ""
        if !author1.isEmpty && !author2.isEmpty && author1 != author2 {
            return false
        }
        
        // Must have same series info (if extractable)
        let (series1, volume1) = extractSeriesInfo(from: book1.volumeInfo.title)
        let (series2, volume2) = extractSeriesInfo(from: book2.volumeInfo.title)
        
        if let s1 = series1, let s2 = series2 {
            if s1.lowercased() != s2.lowercased() { return false }
            if let v1 = volume1, let v2 = volume2, v1 != v2 { return false }
        }
        
        // Check publication date similarity (within 3 years for different editions)
        if let date1 = parsePublishDate(book1.volumeInfo.publishedDate),
           let date2 = parsePublishDate(book2.volumeInfo.publishedDate) {
            let yearDiff = abs(Calendar.current.component(.year, from: date1) - 
                             Calendar.current.component(.year, from: date2))
            if yearDiff > 3 { return false }
        }
        
        return true
    }
    
    /// Calculates confidence score for consolidation
    private func calculateConsolidationConfidence(_ books: [GoogleBook]) -> Double {
        guard books.count > 1 else { return 0.0 }
        
        var confidence = 0.7 // Base confidence
        
        // Higher confidence for more books
        confidence += min(0.2, Double(books.count - 1) * 0.1)
        
        // Higher confidence if all have same author
        let authors = books.compactMap { $0.volumeInfo.authors?.first?.lowercased() }
        if Set(authors).count == 1 && !authors.isEmpty {
            confidence += 0.1
        }
        
        // Higher confidence if all have ISBNs
        let hasISBNs = books.allSatisfy { !($0.volumeInfo.industryIdentifiers?.isEmpty ?? true) }
        if hasISBNs {
            confidence += 0.1
        }
        
        return min(1.0, confidence)
    }
    
    /// Creates a consolidated book from multiple source books
    private func createConsolidatedBook(from books: [GoogleBook]) -> GoogleBook {
        guard let primaryBook = selectPrimaryBook(from: books) else {
            return books.first!
        }
        
        // Create enhanced volume info by merging data
        let enhancedVolumeInfo = GoogleBook.VolumeInfo(
            title: selectBestTitle(from: books),
            authors: selectBestAuthors(from: books),
            publisher: selectBestPublisher(from: books),
            publishedDate: selectBestPublishDate(from: books),
            description: selectBestDescription(from: books),
            imageLinks: selectBestImageLinks(from: books),
            industryIdentifiers: mergeAllISBNs(from: books),
            pageCount: selectBestPageCount(from: books),
            categories: mergeCategories(from: books),
            averageRating: selectBestRating(from: books),
            ratingsCount: selectBestRatingCount(from: books),
            language: primaryBook.volumeInfo.language,
            mainCategory: primaryBook.volumeInfo.mainCategory
        )
        
        return GoogleBook(
            id: primaryBook.id, // Keep primary book's ID
            volumeInfo: enhancedVolumeInfo
        )
    }
    
    /// Selects the primary book (best quality data) from the group
    private func selectPrimaryBook(from books: [GoogleBook]) -> GoogleBook? {
        return books.max { book1, book2 in
            var score1 = 0
            var score2 = 0
            
            // Prefer books with images
            if book1.volumeInfo.imageLinks?.thumbnail != nil { score1 += 3 }
            if book2.volumeInfo.imageLinks?.thumbnail != nil { score2 += 3 }
            
            // Prefer books with descriptions
            if !(book1.volumeInfo.description?.isEmpty ?? true) { score1 += 2 }
            if !(book2.volumeInfo.description?.isEmpty ?? true) { score2 += 2 }
            
            // Prefer books with more metadata
            if book1.volumeInfo.pageCount != nil { score1 += 1 }
            if book2.volumeInfo.pageCount != nil { score2 += 1 }
            
            if book1.volumeInfo.categories?.isEmpty == false { score1 += 1 }
            if book2.volumeInfo.categories?.isEmpty == false { score2 += 1 }
            
            return score1 < score2
        }
    }
    
    /// Selects the best title (most complete/descriptive)
    private func selectBestTitle(from books: [GoogleBook]) -> String {
        return books.map { $0.volumeInfo.title }
                   .max { $0.count < $1.count } ?? books.first!.volumeInfo.title
    }
    
    /// Selects the best authors array
    private func selectBestAuthors(from books: [GoogleBook]) -> [String]? {
        return books.compactMap { $0.volumeInfo.authors }
                   .max { $0.count < $1.count }
    }
    
    /// Selects the best publisher
    private func selectBestPublisher(from books: [GoogleBook]) -> String? {
        let publishers = books.compactMap { $0.volumeInfo.publisher }
        
        // Prefer official publisher names over generic ones
        let officialPublishers = publishers.filter { !$0.lowercased().contains("books") }
        if !officialPublishers.isEmpty {
            return officialPublishers.first
        }
        
        return publishers.first
    }
    
    /// Selects the best publication date (most recent for reprints)
    private func selectBestPublishDate(from books: [GoogleBook]) -> String? {
        let dates = books.compactMap { $0.volumeInfo.publishedDate }
        return dates.max() // String comparison works for YYYY-MM-DD format
    }
    
    /// Selects the best description (longest, most detailed)
    private func selectBestDescription(from books: [GoogleBook]) -> String? {
        return books.compactMap { $0.volumeInfo.description }
                   .filter { !$0.isEmpty }
                   .max { $0.count < $1.count }
    }
    
    /// Selects the best image links (highest quality)
    private func selectBestImageLinks(from books: [GoogleBook]) -> GoogleBook.VolumeInfo.ImageLinks? {
        return books.compactMap { $0.volumeInfo.imageLinks }
                   .max { links1, links2 in
                       // Prefer links with larger images
                       let score1 = (links1.large != nil ? 4 : 0) +
                                   (links1.medium != nil ? 3 : 0) +
                                   (links1.small != nil ? 2 : 0) +
                                   (links1.thumbnail != nil ? 1 : 0)
                       
                       let score2 = (links2.large != nil ? 4 : 0) +
                                   (links2.medium != nil ? 3 : 0) +
                                   (links2.small != nil ? 2 : 0) +
                                   (links2.thumbnail != nil ? 1 : 0)
                       
                       return score1 < score2
                   }
    }
    
    /// Merges all ISBNs from all books
    private func mergeAllISBNs(from books: [GoogleBook]) -> [GoogleBook.VolumeInfo.IndustryIdentifier] {
        var allIdentifiers: [GoogleBook.VolumeInfo.IndustryIdentifier] = []
        var seenIdentifiers: Set<String> = []
        
        for book in books {
            if let identifiers = book.volumeInfo.industryIdentifiers {
                for identifier in identifiers {
                    if !seenIdentifiers.contains(identifier.identifier) {
                        allIdentifiers.append(identifier)
                        seenIdentifiers.insert(identifier.identifier)
                    }
                }
            }
        }
        
        return allIdentifiers
    }
    
    /// Extracts all ISBN strings from books
    private func extractAllISBNs(from books: [GoogleBook]) -> [String] {
        var allISBNs: [String] = []
        var seenISBNs: Set<String> = []
        
        for book in books {
            if let identifiers = book.volumeInfo.industryIdentifiers {
                for identifier in identifiers {
                    if !seenISBNs.contains(identifier.identifier) {
                        allISBNs.append(identifier.identifier)
                        seenISBNs.insert(identifier.identifier)
                    }
                }
            }
        }
        
        return allISBNs
    }
    
    /// Selects the best page count
    private func selectBestPageCount(from books: [GoogleBook]) -> Int? {
        return books.compactMap { $0.volumeInfo.pageCount }.max()
    }
    
    /// Merges categories from all books
    private func mergeCategories(from books: [GoogleBook]) -> [String]? {
        var allCategories: Set<String> = []
        
        for book in books {
            if let categories = book.volumeInfo.categories {
                allCategories.formUnion(categories)
            }
        }
        
        return allCategories.isEmpty ? nil : Array(allCategories)
    }
    
    /// Selects the best rating
    private func selectBestRating(from books: [GoogleBook]) -> Double? {
        return books.compactMap { $0.volumeInfo.averageRating }.max()
    }
    
    /// Selects the best rating count
    private func selectBestRatingCount(from books: [GoogleBook]) -> Int? {
        return books.compactMap { $0.volumeInfo.ratingsCount }.max()
    }
    
    // MARK: - Helper Methods
    
    /// Normalizes title for comparison
    private func normalizeTitle(_ title: String) -> String {
        return title.lowercased()
                   .replacingOccurrences(of: ",", with: "")
                   .replacingOccurrences(of: ".", with: "")
                   .replacingOccurrences(of: ":", with: "")
                   .replacingOccurrences(of: "-", with: " ")
                   .replacingOccurrences(of: "  ", with: " ")
                   .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Calculates title similarity (simple Levenshtein-based)
    private func titleSimilarity(_ title1: String, _ title2: String) -> Double {
        let distance = levenshteinDistance(title1, title2)
        let maxLength = max(title1.count, title2.count)
        return maxLength == 0 ? 1.0 : 1.0 - (Double(distance) / Double(maxLength))
    }
    
    /// Simple Levenshtein distance calculation
    private func levenshteinDistance(_ str1: String, _ str2: String) -> Int {
        let arr1 = Array(str1)
        let arr2 = Array(str2)
        let m = arr1.count
        let n = arr2.count
        
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m { dp[i][0] = i }
        for j in 0...n { dp[0][j] = j }
        
        for i in 1...m {
            for j in 1...n {
                if arr1[i-1] == arr2[j-1] {
                    dp[i][j] = dp[i-1][j-1]
                } else {
                    dp[i][j] = 1 + min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1])
                }
            }
        }
        
        return dp[m][n]
    }
    
    /// Parses publication date string to Date
    private func parsePublishDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        
        let formatter = DateFormatter()
        
        // Try different date formats
        let formats = ["yyyy-MM-dd", "yyyy-MM", "yyyy"]
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        return nil
    }
    
    /// Extracts series and volume info from title (reuse existing logic)
    private func extractSeriesInfo(from title: String) -> (String?, Int?) {
        return VolumeExtractor.extractSeriesAndVolume(from: title)
    }
}

// MARK: - VolumeExtractor Extension

extension VolumeExtractor {
    /// Extracts both series and volume in one call
    static func extractSeriesAndVolume(from title: String) -> (String?, Int?) {
        let series = extractSeriesName(from: title)
        let volume = extractVolumeNumber(from: title)
        return (series, volume)
    }
}
