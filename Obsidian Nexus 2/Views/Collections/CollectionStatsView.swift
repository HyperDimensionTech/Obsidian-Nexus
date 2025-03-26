import SwiftUI

struct CollectionStatsView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    
    var body: some View {
        List {
            TotalValueSection(value: inventoryViewModel.totalCollectionValue)
            
            CollectionStatisticsSection(stats: inventoryViewModel.collectionStats)
            
            if !inventoryViewModel.mangaSeries().isEmpty {
                MangaSeriesSection(series: inventoryViewModel.mangaSeries())
            }
        }
        .navigationTitle("Collection Stats")
    }
}

// MARK: - Supporting Views

private struct TotalValueSection: View {
    let value: Price
    
    var body: some View {
        Section("Total Collection Value") {
            HStack {
                Text("Value")
                Spacer()
                Text(value.convertedToDefaultCurrency().formatted())
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct CollectionStatisticsSection: View {
    let stats: [(type: CollectionType, count: Int, value: Price)]
    
    var body: some View {
        Section("Collection Statistics") {
            ForEach(stats, id: \.type) { stat in
                HStack {
                    Text(stat.type.name)
                    Spacer()
                    Text("\(stat.count) items")
                        .foregroundColor(.secondary)
                    Text(stat.value.convertedToDefaultCurrency().formatted())
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

private struct MangaSeriesSection: View {
    let series: [(String, [InventoryItem])]
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    
    var body: some View {
        Section("Manga Series") {
            ForEach(series, id: \.0) { seriesName, items in
                let stats = inventoryViewModel.seriesStats(name: seriesName)
                NavigationLink {
                    SeriesDetailView(series: seriesName)
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(seriesName)
                            Text("\(items.count) volumes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(stats.value.convertedToDefaultCurrency().formatted())
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        CollectionStatsView()
            .environmentObject(InventoryViewModel(locationManager: LocationManager()))
    }
} 