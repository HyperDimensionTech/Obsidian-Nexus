import SwiftUI

struct CollectionDetailView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    let type: CollectionType
    
    var body: some View {
        Group {
            if type == .manga {
                MangaSeriesView()
            } else {
                ItemListView(items: inventoryViewModel.items(for: type))
            }
        }
        .navigationTitle(type.name)
    }
} 