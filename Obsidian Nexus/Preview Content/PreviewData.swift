import Foundation

@MainActor
class PreviewData {
    static let shared = PreviewData()
    
    let locationManager: LocationManager
    let inventoryViewModel: InventoryViewModel
    
    private init() {
        locationManager = LocationManager()
        inventoryViewModel = InventoryViewModel(locationManager: locationManager)
        
        // Load sample data
        locationManager.loadSampleData()
        inventoryViewModel.loadSampleData()
    }
} 