import SwiftUI

struct SearchResultsView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var locationManager: LocationManager
    let searchOptions: SearchOptions
    
    var filteredItems: [InventoryItem] {
        inventoryViewModel.items.filter { item in
            searchOptions.matches(item, locationManager: locationManager)
        }
    }
    
    var body: some View {
        List(filteredItems) { item in
            ItemRow(item: item)
        }
    }
} 