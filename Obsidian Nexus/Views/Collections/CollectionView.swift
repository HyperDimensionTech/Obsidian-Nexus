import SwiftUI

struct CollectionView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var locationManager: LocationManager
    let type: CollectionType
    
    var items: [InventoryItem] {
        inventoryViewModel.items(for: type)
    }
    
    var body: some View {
        List {
            if type == .manga {
                // Group manga by series
                ForEach(inventoryViewModel.mangaSeries(), id: \.0) { series, seriesItems in
                    NavigationLink {
                        SeriesDetailView(series: series)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(series)
                                .font(.headline)
                            Text("\(seriesItems.count) volumes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                // Show individual items for other collection types
                ForEach(items) { item in
                    NavigationLink {
                        ItemDetailView(item: item)
                    } label: {
                        ItemRow(item: item)
                    }
                }
            }
        }
        .navigationTitle(type.name)
    }
}

#Preview {
    let locationManager = LocationManager()
    return NavigationView {
        CollectionView(type: .books)
            .environmentObject(InventoryViewModel(locationManager: locationManager))
            .environmentObject(locationManager)
    }
} 