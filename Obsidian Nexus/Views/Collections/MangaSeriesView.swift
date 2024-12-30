import SwiftUI

struct MangaSeriesView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    
    var body: some View {
        List {
            ForEach(inventoryViewModel.mangaSeries(), id: \.0) { series, volumes in
                NavigationLink(destination: SeriesDetailView(series: series, volumes: volumes)) {
                    HStack {
                        Text(series)
                        Spacer()
                        Text("\(volumes.count) volumes")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Manga Series")
    }
} 