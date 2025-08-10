import SwiftUI

struct BooksByAuthorView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    let author: String
    
    var authorItems: [InventoryItem] {
        inventoryViewModel.itemsByAuthor(author)
    }
    
    var authorStats: (value: Price, count: Int) {
        inventoryViewModel.authorStats(name: author)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Author stats section
            List {
                Section {
                    HStack {
                        Text("Total Value")
                        Spacer()
                        Text(authorStats.value.convertedToDefaultCurrency().formatted())
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Number of Books")
                        Spacer()
                        Text("\(authorStats.count)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .frame(height: 120)
            
            // Books list using ItemListComponent
            ItemListComponent(
                items: authorItems,
                sectionTitle: "Books",
                groupingStyle: .none,
                sortStyle: .title
            )
        }
        .navigationTitle(author)
    }
} 