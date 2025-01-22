import SwiftUI

struct SearchView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @State private var searchText = ""
    @State private var selectedFilter: SearchFilter = .all
    @State private var isLoading = false
    
    var filteredItems: [InventoryItem] {
        let searchResults = inventoryViewModel.searchItems(query: searchText)
        if selectedFilter == .all {
            return searchResults
        }
        return searchResults.filter { $0.type == selectedFilter.collectionType }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            SearchBar(text: $searchText)
                .padding()
            
            SearchFilterBar(selectedFilter: $selectedFilter)
            
            if searchText.isEmpty {
                SearchSuggestions()
            } else if filteredItems.isEmpty {
                SearchEmptyState(searchText: searchText)
            } else {
                List(filteredItems) { item in
                    NavigationLink(destination: ItemDetailView(item: item)) {
                        SearchResultRow(item: item)
                    }
                }
            }
            
            if isLoading {
                ProgressView()
            }
        }
        .navigationTitle("Search")
    }
}

enum SearchFilter: String, CaseIterable {
    case all = "All"
    case manga = "Manga"
    case books = "Books"
    case comics = "Comics"
    
    var collectionType: CollectionType? {
        switch self {
        case .all: return nil
        case .manga: return .manga
        case .books: return .books
        case .comics: return .comics
        }
    }
} 