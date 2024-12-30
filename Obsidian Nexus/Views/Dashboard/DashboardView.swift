import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                StatsOverviewCard()
                
                CollectionGridView()
                
                RecentItemsSection()
            }
            .padding()
        }
        .navigationTitle("Dashboard")
    }
}

struct CollectionGridView: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text("Collections")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                ForEach(CollectionType.allCases) { type in
                    NavigationLink(destination: CollectionDetailView(type: type)) {
                        CollectionGridItem(type: type)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}

struct CollectionGridItem: View {
    let type: CollectionType
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    
    var body: some View {
        VStack {
            Image(systemName: type.iconName)
                .font(.largeTitle)
                .foregroundColor(type.color)
            
            Text(type.name)
                .font(.headline)
                .lineLimit(1)
            
            Text("\(inventoryViewModel.itemCount(for: type)) items")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
} 