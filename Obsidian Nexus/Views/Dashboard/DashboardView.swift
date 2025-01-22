import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    
    var body: some View {
        NavigationStack {
            List {
                // Collection Overview Section
                Section {
                    NavigationLink {
                        CollectionStatsView()
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Collection Overview")
                                .font(.headline)
                            
                            HStack {
                                Text("\(inventoryViewModel.totalItems) Items")
                                Text("•")
                                Text(inventoryViewModel.totalCollectionValue
                                    .formatted(.currency(code: "USD")))
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Collections Section (existing)
                Section("Collections") {
                    ForEach(CollectionType.literatureTypes, id: \.self) { type in
                        NavigationLink {
                            CollectionView(type: type)
                        } label: {
                            Label {
                                HStack {
                                    Text(type.name)
                                    Spacer()
                                    Text("\(inventoryViewModel.itemCount(for: type))")
                                        .foregroundColor(.secondary)
                                }
                            } icon: {
                                Image(systemName: type.iconName)
                            }
                        }
                    }
                }
                
                // Recent Items Section (existing)
                if !inventoryViewModel.recentItems.isEmpty {
                    Section("Recent Items") {
                        ForEach(inventoryViewModel.recentItems) { item in
                            NavigationLink {
                                ItemDetailView(item: item)
                            } label: {
                                ItemRow(item: item)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Dashboard")
        }
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