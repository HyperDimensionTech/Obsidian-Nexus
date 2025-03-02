import SwiftUI

// MARK: - Sort Options
enum SortOption: String, CaseIterable, Identifiable {
    case titleAsc = "Title (A-Z)"
    case titleDesc = "Title (Z-A)"
    case dateAddedNewest = "Date Added (Newest)"
    case dateAddedOldest = "Date Added (Oldest)"
    case authorAsc = "Author (A-Z)"
    case authorDesc = "Author (Z-A)"
    case conditionBest = "Condition (Best)"
    case conditionWorst = "Condition (Worst)"
    
    var id: String { rawValue }
    
    func sortItems(_ items: [InventoryItem]) -> [InventoryItem] {
        switch self {
        case .titleAsc:
            return items.sorted { $0.title.lowercased() < $1.title.lowercased() }
        case .titleDesc:
            return items.sorted { $0.title.lowercased() > $1.title.lowercased() }
        case .dateAddedNewest:
            return items.sorted { $0.dateAdded > $1.dateAdded }
        case .dateAddedOldest:
            return items.sorted { $0.dateAdded < $1.dateAdded }
        case .authorAsc:
            return items.sorted {
                let author1 = $0.author?.lowercased() ?? ""
                let author2 = $1.author?.lowercased() ?? ""
                return author1 < author2
            }
        case .authorDesc:
            return items.sorted {
                let author1 = $0.author?.lowercased() ?? ""
                let author2 = $1.author?.lowercased() ?? ""
                return author1 > author2
            }
        case .conditionBest:
            return items.sorted {
                let order1 = conditionOrder($0.condition)
                let order2 = conditionOrder($1.condition)
                return order1 < order2
            }
        case .conditionWorst:
            return items.sorted {
                let order1 = conditionOrder($0.condition)
                let order2 = conditionOrder($1.condition)
                return order1 > order2
            }
        }
    }
    
    private func conditionOrder(_ condition: ItemCondition) -> Int {
        switch condition {
        case .new: return 0
        case .likeNew: return 1
        case .good: return 2
        case .fair: return 3
        case .poor: return 4
        }
    }
}

struct SearchView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @State private var searchText = ""
    @State private var selectedFilter: SearchFilter = .all
    @State private var showingSearchResults = false
    @State private var selectedSortOption: SortOption = .titleAsc
    @State private var showingSortOptions = false
    
    var filteredItems: [InventoryItem] {
        let searchResults = inventoryViewModel.searchItems(query: searchText)
        let filtered = selectedFilter == .all ? 
            searchResults : 
            searchResults.filter { $0.type == selectedFilter.collectionType }
        
        // Apply sorting
        return selectedSortOption.sortItems(filtered)
    }
    
    var body: some View {
        NavigationStack(path: $navigationCoordinator.path) {
            VStack(spacing: 0) {
                // Search bar at the top
                SearchBar(text: $searchText)
                    .padding()
                    .onChange(of: searchText) { _, newValue in
                        showingSearchResults = !newValue.isEmpty
                    }
                
                // Filter bar below search
                SearchFilterBar(selectedFilter: $selectedFilter)
                
                // Main content area
                if showingSearchResults {
                    // Show search results
                    if filteredItems.isEmpty {
                        EmptySearchView(query: searchText)
                    } else {
                        VStack(spacing: 0) {
                            // Sort options bar
                            HStack {
                                Text("\(filteredItems.count) results")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Button(action: {
                                    showingSortOptions = true
                                }) {
                                    HStack {
                                        Text("Sort: \(selectedSortOption.rawValue)")
                                            .font(.subheadline)
                                        Image(systemName: "arrow.up.arrow.down")
                                    }
                                }
                                .foregroundColor(.primary)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            
                            // Results list
                            List {
                                ForEach(filteredItems) { item in
                                    ItemRow(item: item)
                                }
                            }
                            .listStyle(.plain)
                        }
                        .confirmationDialog("Sort By", isPresented: $showingSortOptions, titleVisibility: .visible) {
                            ForEach(SortOption.allCases) { option in
                                Button(option.rawValue) {
                                    selectedSortOption = option
                                }
                            }
                            Button("Cancel", role: .cancel) {}
                        }
                    }
                } else {
                    // Show collections grid when not searching
                    ScrollView {
                        VStack(alignment: .leading) {
                            Text("Collections")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                                .padding(.top)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 16),
                                GridItem(.flexible(), spacing: 16)
                            ], spacing: 16) {
                                ForEach(CollectionType.literatureTypes, id: \.self) { type in
                                    NavigationLink(value: type) {
                                        CollectionCard(type: type)
                                            .frame(maxWidth: .infinity)
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Browse & Search")
            .navigationDestination(for: CollectionType.self) { type in
                CollectionDetailView(type: type)
            }
        }
        .onAppear {
            // Add notification observer when view appears
            NotificationCenter.default.addObserver(
                forName: Notification.Name("TabDoubleTapped"),
                object: nil,
                queue: .main
            ) { notification in
                // Only respond to search tab double-taps
                if let tab = notification.object as? String, tab == "Browse & Search" {
                    // Clear search when Search tab is double-tapped
                    searchText = ""
                    selectedFilter = .all
                    showingSearchResults = false
                    
                    // Reset navigation
                    DispatchQueue.main.async {
                        navigationCoordinator.navigateToRoot()
                    }
                }
            }
        }
    }
}

#Preview {
    SearchView()
        .environmentObject(InventoryViewModel(locationManager: LocationManager()))
        .environmentObject(NavigationCoordinator())
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