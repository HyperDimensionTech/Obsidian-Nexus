import SwiftUI

struct CollectionDetailView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    let type: CollectionType
    
    var body: some View {
        CollectionView(type: type)
            .environmentObject(inventoryViewModel)
            .environmentObject(locationManager)
            .environmentObject(navigationCoordinator)
    }
} 