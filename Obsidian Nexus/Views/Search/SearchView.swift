import SwiftUI

struct SearchView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @State private var searchText = ""
    @State private var selectedFilter: SearchFilter = .all
    
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
                EmptySearchView(query: searchText)
            } else {
                List {
                    ForEach(filteredItems) { item in
                        ItemRow(item: item)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Search")
    }
}

// MARK: - Empty Search View
private struct EmptySearchView: View {
    let query: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No results found for \"\(query)\"")
                .font(.headline)
            Text("Try adjusting your search terms")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
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