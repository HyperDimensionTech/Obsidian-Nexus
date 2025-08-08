//
//  ServiceContainer.swift
//  Pocket Dimension
//
//  Service container for managing shared services and dependencies
//

import Foundation

@MainActor
class ServiceContainer: ObservableObject {
    static let shared = ServiceContainer()
    
    // Shared service instances
    lazy var googleBooksService = GoogleBooksService()
    lazy var isbnMappingService = ISBNMappingService(storage: .shared)
    lazy var thumbnailService = ThumbnailService()
    lazy var barcodeScannerService = BarcodeScannerService()
    lazy var openLibraryService = OpenLibraryService()
    lazy var currencyManager = CurrencyManager.shared
    lazy var qrCodeService = QRCodeService.shared
    
    // New inventory services
    lazy var inventoryValidationService = InventoryValidationService()
    lazy var inventorySearchService = InventorySearchService()
    lazy var inventoryStatsService = InventoryStatsService()
    lazy var collectionManagementService = CollectionManagementService()
    lazy var enhancedImageProcessingService = EnhancedImageProcessingService.shared
    
    private init() {
        print("🟢 ServiceContainer: Initialized shared services")
    }
    
    deinit {
        print("🔴 ServiceContainer: Deallocating")
    }
    
    // Helper method to get barcode scanner view model
    func createBarcodeScannerViewModel() -> BarcodeScannerViewModel {
        return BarcodeScannerViewModel()
    }
    
    // Helper method to create image saver
    func createImageSaver() -> ImageSaver {
        return ImageSaver()
    }
} 