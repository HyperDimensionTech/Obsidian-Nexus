import SwiftUI

struct RecentItemsSection: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Items")
                .font(.headline)
            
            ForEach(inventoryViewModel.recentItems) { item in
                NavigationLink(destination: ItemDetailView(item: item)) {
                    RecentItemRow(item: item)
                }
            }
        }
    }
}

struct RecentItemRow: View {
    let item: InventoryItem
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(item.title)
                    .font(.headline)
                if let series = item.series {
                    Text(series)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Image(systemName: item.type.iconName)
                    .foregroundColor(item.type.color)
                Text(item.dateAdded.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
} 