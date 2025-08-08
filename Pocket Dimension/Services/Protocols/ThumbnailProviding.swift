import Foundation

public protocol ThumbnailProviding {
    func fetchThumbnail(for item: InventoryItem, completion: @escaping (URL?) -> Void)
}


