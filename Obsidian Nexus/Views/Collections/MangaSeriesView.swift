import SwiftUI

struct MangaSeriesView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    
    var body: some View {
        List {
            ForEach(inventoryViewModel.mangaSeries(), id: \.0) { series, items in
                let stats = inventoryViewModel.seriesStats(name: series)
                NavigationLink {
                    SeriesDetailView(series: series)
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(series)
                                .font(.headline)
                            Text("\(items.count) volumes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(stats.value.formatted(.currency(code: "USD")))
                            Text("Total Value")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Manga Series")
    }
}

#Preview {
    NavigationView {
        MangaSeriesView()
            .environmentObject(InventoryViewModel(locationManager: LocationManager()))
    }
} 