import Foundation

@MainActor
class PreviewData {
    static let shared = PreviewData()
    
    let locationManager: LocationManager
    let inventoryViewModel: InventoryViewModel
    
    private init() {
        locationManager = LocationManager()
        inventoryViewModel = InventoryViewModel(storage: ServiceContainer.shared.storage,
                                                locationManager: locationManager,
                                                validator: ServiceContainer.shared.validator,
                                                search: ServiceContainer.shared.search,
                                                stats: ServiceContainer.shared.stats,
                                                collectionService: CollectionManagementService())
        
        // Load sample data
        locationManager.loadSampleData()
        inventoryViewModel.loadSampleData()
    }
} 