import UIKit

actor ImageCache {
    static let shared = ImageCache()
    private var cache: [URL: UIImage] = [:]
    
    func image(for url: URL) -> UIImage? {
        return cache[url]
    }
    
    func insert(_ image: UIImage, for url: URL) {
        cache[url] = image
    }
    
    func removeImage(for url: URL) {
        cache.removeValue(forKey: url)
    }
    
    func clearCache() {
        cache.removeAll()
    }
} 