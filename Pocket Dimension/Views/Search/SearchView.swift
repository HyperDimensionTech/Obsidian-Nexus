import SwiftUI

// Enhanced search result type to handle different result types including series
enum SearchResultItem: Identifiable {
    case item(InventoryItem)
    case location(StorageLocation)
    case series(String, CollectionType, Int) // series name, type, item count
    
    var id: String {
        switch self {
        case .item(let item):
            return "item-\(item.id)"
        case .location(let location):
            return "location-\(location.id)"
        case .series(let name, let type, _):
            return "series-\(type.rawValue)-\(name)"
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
                    
                    TextField("Search items, series, locations...", text: $searchText)
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
                if !searchText.isEmpty {
                    // No search results found
                    VStack(spacing: 24) {
                        Spacer()
                        
                        Text("No results found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Try a different search term")
                            .foregroundColor(.gray)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    // Empty state with collections grid
                    ScrollView {
                        VStack(spacing: 24) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            
                            Text("Search for items, series, or locations")
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
                            
                            // Collections grid for easy browsing
                            CollectionsGrid()
                                .environmentObject(inventoryViewModel)
                                .environmentObject(navigationCoordinator)
                        }
                        .padding()
                    }
                }
            } else {
                List {
                    // Show series first (most relevant for collection browsing)
                    let seriesResults = searchResults.compactMap { result -> (String, CollectionType, Int)? in
                        if case .series(let name, let type, let count) = result {
                            return (name, type, count)
                        }
                        return nil
                    }
                    
                    if !seriesResults.isEmpty {
                        Section(header: Text("Series")) {
                            ForEach(seriesResults, id: \.0) { seriesName, type, count in
                                NavigationLink {
                                    SeriesDetailView(series: seriesName, collectionType: type)
                                        .environmentObject(locationManager)
                                        .environmentObject(inventoryViewModel)
                                        .environmentObject(navigationCoordinator)
                                } label: {
                                    HStack {
                                        Image(systemName: type.iconName)
                                            .foregroundColor(type.color)
                                        VStack(alignment: .leading) {
                                            Text(seriesName)
                                                .foregroundColor(.primary)
                                            Text("\(count) \(type.seriesItemTerminology)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Show locations second
                    let locationResults = searchResults.compactMap { result -> StorageLocation? in
                        if case .location(let location) = result {
                            return location
                        }
                        return nil
                    }
                    
                    if !locationResults.isEmpty {
                        Section(header: Text("Locations")) {
                            ForEach(locationResults) { location in
                                NavigationLink(destination: LocationItemsView(location: location)
                                    .environmentObject(locationManager)
                                    .environmentObject(inventoryViewModel)
                                    .environmentObject(navigationCoordinator)
                                ) {
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
                    
                    // Show individual items last
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
        
        // Perform search on main actor since our view models are MainActor-isolated
        Task { @MainActor in
            var results: [SearchResultItem] = []
            
            // Search for series across all collection types
            let query = searchText.lowercased()
            for type in CollectionType.allCases {
                if type.supportsSeriesGrouping {
                    let seriesData = inventoryViewModel.seriesForType(type)
                    let matchingSeries = seriesData.filter { seriesName, _ in
                        seriesName.lowercased().contains(query)
                    }
                    
                    results.append(contentsOf: matchingSeries.map { seriesName, items in
                        SearchResultItem.series(seriesName, type, items.count)
                    })
                }
            }
            
            // Search for individual items
            let itemResults = inventoryViewModel.searchItems(query: searchText)
            results.append(contentsOf: itemResults.map { SearchResultItem.item($0) })
            
            // Search for locations
            let locationResults = locationManager.searchLocations(query: searchText)
            results.append(contentsOf: locationResults.map { SearchResultItem.location($0) })
            
            searchResults = results
            isLoading = false
        }
    }
}

#Preview {
    SearchView()
        .environmentObject(InventoryViewModel(locationManager: LocationManager()))
        .environmentObject(NavigationCoordinator())
} 