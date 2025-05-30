import SwiftUI

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
        
        // Perform search on main actor since our view models are MainActor-isolated
        Task { @MainActor in
            var results: [SearchResultItem] = []
            
            // Search for items
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