import SwiftUI

struct ItemListView: View {
    let items: [InventoryItem]
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    // Configuration options
    var navigationTitle: String = "Items"
    var groupingStyle: ItemListComponent.GroupingStyle = .none
    var sortStyle: ItemListComponent.SortStyle = .title
    var useCoordinator: Bool = false
    
    var body: some View {
        ItemListComponent(
            items: items,
            sectionTitle: navigationTitle,
            groupingStyle: groupingStyle,
            sortStyle: sortStyle,
            useCoordinator: useCoordinator
        )
        .navigationTitle(navigationTitle)
    }
}

#Preview {
    ItemListView(items: [])
        .environmentObject(LocationManager())
        .environmentObject(InventoryViewModel(locationManager: LocationManager()))
        .environmentObject(NavigationCoordinator())
} 