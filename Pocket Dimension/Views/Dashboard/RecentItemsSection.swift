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
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var userPreferences: UserPreferences
    let item: InventoryItem
    
    private var locationPath: String? {
        guard let id = item.locationId else { return nil }
        return locationManager.breadcrumbPath(for: id)
    }
    
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
                // Type icon is always shown in recent items
                Image(systemName: item.type.iconName)
                    .foregroundColor(item.type.color)
                
                // Secondary info based on preferences
                HStack(spacing: 4) {
                    // For recent items, we always show date added
                    Text(item.dateAdded.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
} 