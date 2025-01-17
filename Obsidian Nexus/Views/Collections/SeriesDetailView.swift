import SwiftUI

struct SeriesDetailView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var locationManager: LocationManager
    let series: String
    
    var items: [InventoryItem] {
        inventoryViewModel.itemsInSeries(series)
            .sorted { ($0.volume ?? 0) < ($1.volume ?? 0) }
    }
    
    var stats: (value: Decimal, count: Int, total: Int?) {
        inventoryViewModel.seriesStats(name: series)
    }
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text("Series Value")
                        .font(.headline)
                    Spacer()
                    Text(stats.value.formatted(.currency(code: "USD")))
                        .bold()
                }
                
                HStack {
                    Text("Volumes")
                        .font(.headline)
                    Spacer()
                    Text("\(stats.count)")
                        .bold()
                }
            }
            
            Section("Volumes") {
                ForEach(items) { item in
                    NavigationLink {
                        ItemDetailView(item: item)
                    } label: {
                        HStack {
                            Text("Volume \(item.volume ?? 0)")
                            Spacer()
                            if let locationId = item.locationId {
                                Text(locationManager.breadcrumbPath(for: locationId))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("No Location")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(series)
    }
}

#Preview {
    NavigationView {
        SeriesDetailView(series: "Sample Series")
            .environmentObject(InventoryViewModel(locationManager: LocationManager()))
            .environmentObject(LocationManager())
    }
} 