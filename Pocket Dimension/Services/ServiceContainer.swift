//
//  ServiceContainer.swift
//  Pocket Dimension
//
//  Service container for managing shared services and dependencies
//

import Foundation
import Combine

@MainActor
class ServiceContainer: ObservableObject {
    static let shared = ServiceContainer()
    
    // Concrete instances (private)
    private lazy var storageManager = StorageManager.shared
    private lazy var _googleBooksService = GoogleBooksService()
    private lazy var _isbnMappingService = ISBNMappingService(storage: storageManager)
    private lazy var _thumbnailService = ThumbnailService()
    private lazy var _openLibraryService = OpenLibraryService()
    private lazy var _inventoryValidationService = InventoryValidationService()
    private lazy var _inventorySearchService = InventorySearchService()
    private lazy var _inventoryStatsService = InventoryStatsService()
    private lazy var _collectionManagementService = CollectionManagementService()
    private lazy var _productLookup = ProductLookupStub()
    private lazy var _codeDetector: CodeTypeDetector = CodeTypeDetectorImpl()
    private lazy var _booksLookup: BooksLookup = _googleBooksService
    private lazy var _searchRouter: SearchRouting = SearchRouter(detector: _codeDetector, books: _booksLookup, products: _productLookup)
    private lazy var _qrCodeService = QRCodeService.shared
    private lazy var _currencyManager = CurrencyManager.shared
    private lazy var _enhancedImageProcessingService = EnhancedImageProcessingService.shared
    private lazy var _barcodeScannerService = BarcodeScannerService()

    // Protocol-typed accessors
    var storage: InventoryStorage { storageManager }
    var validator: InventoryValidating { _inventoryValidationService }
    var search: InventorySearching { _inventorySearchService }
    var stats: CollectionStatsProviding { _inventoryStatsService }
    var isbnMappings: ISBNMappingProviding { _isbnMappingService }
    var booksLookup: BooksLookup { _booksLookup }
    var productLookup: ProductLookup { _productLookup }
    var codeTypeDetector: CodeTypeDetector { _codeDetector }
    var searchRouter: SearchRouting { _searchRouter }
    var qrCode: QRCodeGenerating { _qrCodeService }
    var thumbnails: ThumbnailProviding { _thumbnailService }
    // Backward-compat concrete accessors used by existing views
    var googleBooksService: GoogleBooksService { _googleBooksService }
    var isbnMappingService: ISBNMappingService { _isbnMappingService }
    var enhancedImageProcessingService: EnhancedImageProcessingService { _enhancedImageProcessingService }
    
    // Existing concrete singletons kept private; expose via protocols above
    
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