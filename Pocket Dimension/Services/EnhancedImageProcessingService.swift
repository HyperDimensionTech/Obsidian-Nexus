import Foundation
import UIKit
import SwiftUI

@MainActor
class EnhancedImageProcessingService: ObservableObject {
    static let shared = EnhancedImageProcessingService()
    
    // MARK: - Published Properties
    @Published private(set) var isProcessing = false
    @Published private(set) var processingStatus = ""
    @Published private(set) var batchProgress: Double = 0.0
    
    // MARK: - Dependencies
    private let googleBooksService = GoogleBooksService()
    private let storageManager = StorageManager.shared
    
    // MARK: - Caching System
    private let memoryCache = NSCache<NSString, UIImage>()
    private let urlValidationCache = NSCache<NSString, NSNumber>() // Boolean cache for URL validity
    private let fileManager = FileManager.default
    
    // MARK: - Configuration
    private let maxRetries = 3
    private let retryDelays: [TimeInterval] = [1.0, 2.0, 5.0] // Progressive backoff
    private let batchSize = 10 // Process images in batches to avoid overwhelming the system
    private let imageTimeout: TimeInterval = 15.0
    
    // MARK: - Cache Directory
    private var cacheDirectory: URL? {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("enhanced_thumbnails")
    }
    
    // MARK: - Processing Queue
    private var processingQueue: [UUID: ImageProcessingTask] = [:]
    private let serialQueue = DispatchQueue(label: "enhanced-image-processing", qos: .userInitiated)
    
    // MARK: - Initialization
    init() {
        setupCache()
        print("🖼️ Enhanced Image Processing Service initialized")
    }
    
    private func setupCache() {
        // Create cache directory
        if let cacheDirectory = cacheDirectory {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
        
        // Configure memory cache
        memoryCache.countLimit = 200 // More images in memory
        memoryCache.totalCostLimit = 100 * 1024 * 1024 // 100MB limit
        
        // Configure URL validation cache
        urlValidationCache.countLimit = 500 // Cache URL validity checks
        urlValidationCache.totalCostLimit = 5 * 1024 * 1024 // 5MB limit
    }
}

// MARK: - Core Processing Methods
extension EnhancedImageProcessingService {
    
    /// Process a single item with guaranteed completion (even if image fails)
    func processItemImage(_ item: InventoryItem, 
                         priority: ProcessingPriority = .normal,
                         completion: @escaping (ImageProcessingResult) -> Void) {
        
        // Check if already being processed
        if processingQueue[item.id] != nil {
            completion(.alreadyProcessing)
            return
        }
        
        let task = ImageProcessingTask(
            itemId: item.id,
            title: item.title,
            isbn: item.isbn,
            author: item.author,
            existingURL: item.thumbnailURL,
            priority: priority,
            completion: completion
        )
        
        processingQueue[item.id] = task
        
        Task {
            await processTask(task)
        }
    }
    
    /// Process multiple items with progress tracking
    func processBatchImages(_ items: [InventoryItem], 
                           progressCallback: @escaping (Double, String) -> Void,
                           completion: @escaping ([UUID: ImageProcessingResult]) -> Void) {
        
        Task {
            isProcessing = true
            batchProgress = 0.0
            processingStatus = "Starting batch image processing..."
            
            var results: [UUID: ImageProcessingResult] = [:]
            let totalItems = items.count
            
            // Process in smaller batches to avoid overwhelming the system
            for (batchIndex, batch) in items.chunked(into: batchSize).enumerated() {
                let batchResults = await processBatch(batch, batchIndex: batchIndex)
                results.merge(batchResults) { _, new in new }
                
                // Update progress
                let processed = min((batchIndex + 1) * batchSize, totalItems)
                batchProgress = Double(processed) / Double(totalItems)
                processingStatus = "Processed \(processed) of \(totalItems) images..."
                
                progressCallback(batchProgress, processingStatus)
                
                // Small delay between batches to prevent API rate limiting
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
            
            isProcessing = false
            processingStatus = "Batch processing complete"
            batchProgress = 1.0
            
            completion(results)
        }
    }
    
    /// Enhanced continuous scan processing with guaranteed completion
    func processContinuousScanImage(_ book: GoogleBook, 
                                   originalISBN: String,
                                   completion: @escaping (InventoryItem, Bool) -> Void) {
        
        Task {
            // Step 1: Create the item immediately (race condition prevention)
            let baseItem = createInventoryItemFromBook(book, originalISBN: originalISBN)
            
            // Step 2: Process image in background with guaranteed completion
            let imageResult = await processImageForBook(book, retryCount: 0)
            
            // Step 3: Update item with image result
            let finalItem = updateItemWithImageResult(baseItem, imageResult: imageResult)
            
            // Step 4: Always call completion (never hang the scanning process)
            completion(finalItem, imageResult.isSuccess)
        }
    }
}

// MARK: - Private Processing Methods
private extension EnhancedImageProcessingService {
    
    func processTask(_ task: ImageProcessingTask) async {
        let result = await performImageProcessing(for: task)
        
        // Remove from queue
        processingQueue.removeValue(forKey: task.itemId)
        
        // Call completion
        task.completion(result)
    }
    
    func processBatch(_ items: [InventoryItem], batchIndex: Int) async -> [UUID: ImageProcessingResult] {
        await withTaskGroup(of: (UUID, ImageProcessingResult).self) { group in
            var results: [UUID: ImageProcessingResult] = [:]
            
            for item in items {
                group.addTask {
                    let task = ImageProcessingTask(
                        itemId: item.id,
                        title: item.title,
                        isbn: item.isbn,
                        author: item.author,
                        existingURL: item.thumbnailURL,
                        priority: .batch,
                        completion: { _ in } // No individual completion for batch
                    )
                    
                    let result = await self.performImageProcessing(for: task)
                    return (item.id, result)
                }
            }
            
            for await (itemId, result) in group {
                results[itemId] = result
            }
            
            return results
        }
    }
    
    func performImageProcessing(for task: ImageProcessingTask) async -> ImageProcessingResult {
        // Step 1: Check existing URL validity
        if let existingURL = task.existingURL {
            if await isURLValid(existingURL) {
                // URL is valid, ensure image is cached
                if await cacheImageFromURL(existingURL) {
                    return .success(existingURL)
                }
            }
        }
        
        // Step 2: Search for new image
        if let isbn = task.isbn {
            if let result = await searchImageByISBN(isbn) {
                return result
            }
        }
        
        // Step 3: Fallback to title/author search
        let result = await searchImageByTitleAuthor(task.title, author: task.author)
        return result ?? .noImageFound
    }
    
    func processImageForBook(_ book: GoogleBook, retryCount: Int) async -> ImageProcessingResult {
        // Extract thumbnail URL
        guard let thumbnailString = book.volumeInfo.imageLinks?.thumbnail else {
            return .noImageFound
        }
        
        // Process and validate URL
        let processedURL = processImageURL(thumbnailString)
        guard let url = processedURL else {
            return .invalidURL(thumbnailString)
        }
        
        // Validate and cache image
        if await validateAndCacheImage(url) {
            return .success(url)
        }
        
        // Retry logic for continuous scanning
        if retryCount < maxRetries {
            let delay = retryDelays[min(retryCount, retryDelays.count - 1)]
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            return await processImageForBook(book, retryCount: retryCount + 1)
        }
        
        return .downloadFailed(url)
    }
}

// MARK: - Image Validation and Caching
private extension EnhancedImageProcessingService {
    
    func validateAndCacheImage(_ url: URL) async -> Bool {
        let urlValid = await isURLValid(url)
        if urlValid {
            return await cacheImageFromURL(url)
        }
        return false
    }
    
    func isURLValid(_ url: URL) async -> Bool {
        let cacheKey = url.absoluteString as NSString
        
        // Check cache first
        if let cached = urlValidationCache.object(forKey: cacheKey) {
            return cached.boolValue
        }
        
        // Validate URL by attempting to load it
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD" // Only check headers, don't download content
            request.timeoutInterval = 5.0
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                let isValid = (200...299).contains(httpResponse.statusCode)
                urlValidationCache.setObject(NSNumber(value: isValid), forKey: cacheKey)
                return isValid
            }
        } catch {
            urlValidationCache.setObject(NSNumber(value: false), forKey: cacheKey)
        }
        
        return false
    }
    
    func cacheImageFromURL(_ url: URL) async -> Bool {
        let cacheKey = url.lastPathComponent + "-" + url.host!
        
        // Check memory cache first
        if memoryCache.object(forKey: cacheKey as NSString) != nil {
            return true
        }
        
        // Check disk cache
        if loadImageFromDisk(fileName: cacheKey) != nil {
            return true
        }
        
        // Download and cache
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = imageTimeout
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let image = UIImage(data: data) else {
                return false
            }
            
            // Cache in memory
            memoryCache.setObject(image, forKey: cacheKey as NSString)
            
            // Cache to disk
            saveImageToDisk(image, fileName: cacheKey)
            
            return true
        } catch {
            print("🖼️ Failed to cache image from \(url): \(error)")
            return false
        }
    }
    
    func loadImageFromDisk(fileName: String) -> UIImage? {
        guard let cacheDirectory = cacheDirectory else { return nil }
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }
    
    func saveImageToDisk(_ image: UIImage, fileName: String) {
        guard let cacheDirectory = cacheDirectory,
              let data = image.jpegData(compressionQuality: 0.8) else { return }
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        try? data.write(to: fileURL)
    }
}

// MARK: - Search Methods
private extension EnhancedImageProcessingService {
    
    func searchImageByISBN(_ isbn: String) async -> ImageProcessingResult? {
        return await withCheckedContinuation { continuation in
            googleBooksService.fetchBooks(query: "isbn:\(isbn)") { result in
                switch result {
                case .success(let books):
                    if let book = books.first,
                       let thumbnailString = book.volumeInfo.imageLinks?.thumbnail,
                       let url = self.processImageURL(thumbnailString) {
                        
                        Task {
                            if await self.validateAndCacheImage(url) {
                                continuation.resume(returning: .success(url))
                            } else {
                                continuation.resume(returning: .downloadFailed(url))
                            }
                        }
                    } else {
                        continuation.resume(returning: nil)
                    }
                case .failure:
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    func searchImageByTitleAuthor(_ title: String, author: String?) async -> ImageProcessingResult? {
        var searchQuery = title
        if let author = author {
            searchQuery += " author:\(author)"
        }
        
        return await withCheckedContinuation { continuation in
            googleBooksService.fetchBooks(query: searchQuery) { result in
                switch result {
                case .success(let books):
                    if let book = books.first,
                       let thumbnailString = book.volumeInfo.imageLinks?.thumbnail,
                       let url = self.processImageURL(thumbnailString) {
                        
                        Task {
                            if await self.validateAndCacheImage(url) {
                                continuation.resume(returning: .success(url))
                            } else {
                                continuation.resume(returning: .downloadFailed(url))
                            }
                        }
                    } else {
                        continuation.resume(returning: nil)
                    }
                case .failure:
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    func processImageURL(_ urlString: String) -> URL? {
        var processedString = urlString
        
        // Ensure HTTPS
        if processedString.hasPrefix("http://") {
            processedString = "https://" + processedString.dropFirst(7)
        }
        
        // Optimize Google Books URLs for better quality
        if processedString.contains("books.google.com") {
            processedString = processedString.replacingOccurrences(of: "zoom=1", with: "zoom=2")
            processedString = processedString.replacingOccurrences(of: "&edge=curl", with: "")
        }
        
        return URL(string: processedString)
    }
}

// MARK: - Helper Methods
private extension EnhancedImageProcessingService {
    
    func createInventoryItemFromBook(_ book: GoogleBook, originalISBN: String) -> InventoryItem {
        let thumbnailURL = book.volumeInfo.imageLinks?.thumbnail.flatMap(processImageURL)
        
        return InventoryItem(
            title: book.volumeInfo.title,
            type: .books, // Default type for continuous scanning
            series: nil,
            volume: nil,
            condition: .good,
            notes: nil,
            dateAdded: Date(),
            barcode: originalISBN,
            thumbnailURL: thumbnailURL,
            author: book.volumeInfo.authors?.first,
            manufacturer: nil,
            originalPublishDate: nil,
            publisher: book.volumeInfo.publisher,
            isbn: book.volumeInfo.industryIdentifiers?.first?.identifier ?? originalISBN,
            price: nil,
            purchaseDate: nil,
            synopsis: book.volumeInfo.description,
            imageSource: .googleBooks
        )
    }
    
    func updateItemWithImageResult(_ item: InventoryItem, imageResult: ImageProcessingResult) -> InventoryItem {
        var updatedItem = item
        
        switch imageResult {
        case .success(let url):
            updatedItem.thumbnailURL = url
            updatedItem.imageSource = .googleBooks
        case .downloadFailed, .invalidURL, .noImageFound, .alreadyProcessing:
            // Keep original URL if any, or set to nil
            updatedItem.imageSource = .none
        }
        
        return updatedItem
    }
}

// MARK: - Progressive Enhancement
extension EnhancedImageProcessingService {
    
    /// Find and enhance items missing images
    func enhanceExistingItems() async -> EnhancementReport {
        let allItems = await fetchAllItems()
        let itemsNeedingImages = allItems.filter { needsImageEnhancement($0) }
        
        guard !itemsNeedingImages.isEmpty else {
            return EnhancementReport(
                totalProcessed: 0,
                imagesFound: 0,
                imagesFailed: 0,
                processingTime: 0
            )
        }
        
        let startTime = Date()
        var imagesFound = 0
        var imagesFailed = 0
        
        processBatchImages(itemsNeedingImages) { progress, status in
            // Progress callback
        } completion: { results in
            for (_, result) in results {
                switch result {
                case .success:
                    imagesFound += 1
                case .downloadFailed, .invalidURL, .noImageFound:
                    imagesFailed += 1
                case .alreadyProcessing:
                    break
                }
            }
        }
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        return EnhancementReport(
            totalProcessed: itemsNeedingImages.count,
            imagesFound: imagesFound,
            imagesFailed: imagesFailed,
            processingTime: processingTime
        )
    }
    
    private func needsImageEnhancement(_ item: InventoryItem) -> Bool {
        // Item needs enhancement if:
        // 1. No thumbnail URL at all
        // 2. Has URL but it's invalid
        // 3. Is literature type (books, manga, etc.) but missing image
        
        guard item.type.isLiterature else { return false }
        
        if item.thumbnailURL == nil {
            return true
        }
        
        // Could add more sophisticated checks here
        return false
    }
    
    private func fetchAllItems() async -> [InventoryItem] {
        return await withCheckedContinuation { continuation in
            do {
                let items = try storageManager.loadItems()
                continuation.resume(returning: items)
            } catch {
                print("🖼️ Failed to fetch items for enhancement: \(error)")
                continuation.resume(returning: [])
            }
        }
    }
}

// MARK: - Supporting Types
struct ImageProcessingTask {
    let itemId: UUID
    let title: String
    let isbn: String?
    let author: String?
    let existingURL: URL?
    let priority: ProcessingPriority
    let completion: (ImageProcessingResult) -> Void
}

enum ProcessingPriority {
    case high      // Continuous scanning
    case normal    // User-initiated
    case batch     // Background enhancement
}

enum ImageProcessingResult {
    case success(URL)
    case downloadFailed(URL)
    case invalidURL(String)
    case noImageFound
    case alreadyProcessing
    
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}

struct EnhancementReport {
    let totalProcessed: Int
    let imagesFound: Int
    let imagesFailed: Int
    let processingTime: TimeInterval
    
    var successRate: Double {
        guard totalProcessed > 0 else { return 0 }
        return Double(imagesFound) / Double(totalProcessed)
    }
}

// MARK: - Array Extension for Chunking
private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Cache Management
extension EnhancedImageProcessingService {
    
    /// Clear all cached images and validation cache
    func clearAllCaches() {
        // Clear memory caches
        memoryCache.removeAllObjects()
        urlValidationCache.removeAllObjects()
        
        // Clear disk cache
        if let cacheDirectory = cacheDirectory {
            try? fileManager.removeItem(at: cacheDirectory)
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
        
        print("🖼️ All image caches cleared")
    }
    
    /// Get cache statistics
    func getCacheStatistics() -> CacheStatistics {
        var diskCacheSize: Int64 = 0
        var diskCacheFileCount = 0
        
        if let cacheDirectory = cacheDirectory,
           let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            
            for case let fileURL as URL in enumerator {
                do {
                    let fileAttributes = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                    if let fileSize = fileAttributes.fileSize {
                        diskCacheSize += Int64(fileSize)
                        diskCacheFileCount += 1
                    }
                } catch {
                    // Skip files that can't be read
                }
            }
        }
        
        return CacheStatistics(
            memoryCacheCount: memoryCache.countLimit,
            diskCacheSize: diskCacheSize,
            diskCacheFileCount: diskCacheFileCount,
            urlValidationCacheCount: urlValidationCache.countLimit
        )
    }
}

// MARK: - Supporting Cache Types
struct CacheStatistics {
    let memoryCacheCount: Int
    let diskCacheSize: Int64
    let diskCacheFileCount: Int
    let urlValidationCacheCount: Int
    
    var diskCacheSizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: diskCacheSize)
    }
} 