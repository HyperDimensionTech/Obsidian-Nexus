import SwiftUI

struct SeriesRow: View {
    let series: String
    let volumes: [InventoryItem]
    
    var body: some View {
        HStack {
            Text(series)
            Spacer()
            Text("\(volumes.count) volumes")
                .foregroundColor(.secondary)
        }
    }
} 