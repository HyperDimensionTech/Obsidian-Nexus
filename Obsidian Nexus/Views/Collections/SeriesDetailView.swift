import SwiftUI

struct SeriesDetailView: View {
    let series: String
    let volumes: [InventoryItem]
    
    var body: some View {
        List(volumes.sorted { ($0.volume ?? 0) < ($1.volume ?? 0) }) { item in
            NavigationLink(destination: ItemDetailView(item: item)) {
                HStack {
                    if let volume = item.volume {
                        Text("Vol. \(volume)")
                            .frame(width: 60, alignment: .leading)
                    }
                    VStack(alignment: .leading) {
                        Text(item.title)
                        Text(item.condition.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle(series)
    }
} 