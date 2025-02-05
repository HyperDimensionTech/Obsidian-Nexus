import SwiftUI

struct ItemListView: View {
    let items: [InventoryItem]
    @EnvironmentObject var locationManager: LocationManager
    
    var body: some View {
        List(items) { item in
            NavigationLink(destination: ItemDetailView(item: item)) {
                ItemRow(item: item)
            }
        }
    }
}

#Preview {
    ItemListView(items: [])
        .environmentObject(PreviewData.shared.locationManager)
} 