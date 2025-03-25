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

// Create a search result type to handle different result types
enum SearchResultItem: Identifiable {
    case item(InventoryItem)
    case location(StorageLocation)
    
    var id: String {
        switch self {
        case .item(let item):
            return "item-\(item.id)"
        case .location(let location):
            return "location-\(location.id)"
        }
    }
}

struct SearchView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var locationManager: LocationManager
    
    @State private var searchText = ""
    @State private var showingScanner = false
    @State private var showingFilter = false
    @State private var isLoading = false
    @State private var searchResults: [SearchResultItem] = []
    
    var body: some View {
        VStack {
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search items...", text: $searchText)
                        .onChange(of: searchText) { _, newValue in
                            // Only search when at least 2 characters
                            if newValue.count >= 2 {
                                performSearch()
                            } else if newValue.isEmpty {
                                // Clear results when search is cleared
                                searchResults = []
                            }
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            searchResults = []
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                Button(action: {
                    showingScanner = true
                }) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 20))
                        .padding(8)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            
            if isLoading {
                ProgressView()
                    .padding()
                Spacer()
            } else if searchResults.isEmpty {
                VStack(spacing: 24) {
                    Spacer()
                    
                    if !searchText.isEmpty {
                        Text("No items found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Try a different search term")
                            .foregroundColor(.gray)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("Search for items or scan a code")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        // QR code scan button
                        Button(action: {
                            showingScanner = true
                        }) {
                            HStack {
                                Image(systemName: "qrcode.viewfinder")
                                Text("Scan QR Code")
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    // Show locations first
                    let locationResults = searchResults.compactMap { result -> StorageLocation? in
                        if case .location(let location) = result {
                            return location
                        }
                        return nil
                    }
                    
                    if !locationResults.isEmpty {
                        Section(header: Text("Locations")) {
                            ForEach(locationResults) { location in
                                NavigationLink {
                                    LocationItemsView(location: location)
                                        .environmentObject(locationManager)
                                        .environmentObject(inventoryViewModel)
                                        .environmentObject(navigationCoordinator)
                                } label: {
                                    HStack {
                                        Image(systemName: location.type.icon)
                                            .foregroundColor(.accentColor)
                                        Text(location.name)
                                            .foregroundColor(.primary)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Then show items
                    let itemResults = searchResults.compactMap { result -> InventoryItem? in
                        if case .item(let item) = result {
                            return item
                        }
                        return nil
                    }
                    
                    if !itemResults.isEmpty {
                        Section(header: Text("Items")) {
                            ForEach(itemResults) { item in
                                NavigationLink {
                                    ItemDetailView(item: item)
                                        .environmentObject(locationManager)
                                        .environmentObject(inventoryViewModel)
                                        .environmentObject(navigationCoordinator)
                                } label: {
                                    ItemRow(item: item)
                                }
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
        }
        .navigationTitle("Browse & Search")
        .sheet(isPresented: $showingScanner) {
            NavigationView {
                LocationQRScannerView()
            }
        }
    }
    
    private func performSearch() {
        isLoading = true
        
        // Use a background thread for search to prevent UI lag
        DispatchQueue.global(qos: .userInitiated).async {
            var results: [SearchResultItem] = []
            
            // Search for items
            let itemResults = inventoryViewModel.searchItems(query: searchText)
            results.append(contentsOf: itemResults.map { SearchResultItem.item($0) })
            
            // Search for locations
            let locationResults = locationManager.searchLocations(query: searchText)
            results.append(contentsOf: locationResults.map { SearchResultItem.location($0) })
            
            DispatchQueue.main.async {
                searchResults = results
                isLoading = false
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