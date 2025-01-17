import SwiftUI

struct CollectionStatsView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text("Total Collection Value")
                        .font(.headline)
                    Spacer()
                    Text(inventoryViewModel.totalCollectionValue
                        .formatted(.currency(code: "USD")))
                        .bold()
                }
            }
            
            Section("By Collection Type") {
                ForEach(inventoryViewModel.collectionStats, id: \.type) { stat in
                    HStack {
                        Label(stat.type.name, systemImage: stat.type.iconName)
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(stat.value.formatted(.currency(code: "USD")))
                            Text("\(stat.count) items")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            if !inventoryViewModel.mangaSeries().isEmpty {
                Section("Manga Series") {
                    ForEach(inventoryViewModel.mangaSeries(), id: \.0) { series, items in
                        let stats = inventoryViewModel.seriesStats(name: series)
                        NavigationLink {
                            SeriesDetailView(series: series)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(series)
                                    Text("\(items.count) volumes")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(stats.value.formatted(.currency(code: "USD")))
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Collection Stats")
    }
}

#Preview {
    NavigationView {
        CollectionStatsView()
            .environmentObject(InventoryViewModel(locationManager: LocationManager()))
    }
} 