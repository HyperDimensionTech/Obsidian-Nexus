import SwiftUI

struct FixedSearchContainer: View {
    // Environment objects
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var locationManager: LocationManager
    
    // Configuration
    let showSearchBar: Bool
    
    // State
    @State private var searchText = ""
    @State private var selectedFilter: SearchFilter = .all
    @State private var selectedSortOption: SortOption = .relevance
    @State private var showingSortOptions = false
    @State private var showingQRScanner = false
    
    // Search results state
    @State private var cachedSearchResults: [SearchResultItem] = []
    @State private var cachedItemResults: [InventoryItem] = []
    @State private var cachedLocationResults: [StorageLocation] = []
    
    // Computed properties for view states
    private var isSearching: Bool { !searchText.isEmpty }
    private var hasResults: Bool { !cachedSearchResults.isEmpty }
    
    // Default initializer that shows search bar
    init(showSearchBar: Bool = true) {
        self.showSearchBar = showSearchBar
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background color to ensure consistent appearance
                Color(.systemBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Fixed header section
                    VStack(spacing: 0) {
                        // Search bar with fixed height
                        if showSearchBar {
                            SearchBar(text: $searchText)
                                .frame(height: 44)
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                            
                            // Filter bar with fixed height
                            SearchFilterBar(selectedFilter: $selectedFilter)
                                .frame(height: 52)
                        }
                    }
                    .background(Color(.systemBackground))
                    .frame(height: showSearchBar ? 112 : 0) // Total fixed header height
                    
                    // Content area
                    ZStack {
                        // Collections view (always present, opacity controlled)
                        ScrollView {
                            CollectionsGrid()
                        }
                        .opacity(isSearching ? 0 : 1)
                        
                        // Search results (always present, opacity controlled)
                        VStack(spacing: 0) {
                            if hasResults {
                                // Results header
                                SearchResultsHeader(
                                    resultCount: cachedSearchResults.count,
                                    sortOption: selectedSortOption,
                                    showingSortOptions: $showingSortOptions
                                )
                                .frame(height: 44)
                                
                                // Results list
                                SearchResultsList(
                                    itemResults: cachedItemResults,
                                    locationResults: cachedLocationResults
                                )
                            } else {
                                // Empty results view
                                EmptySearchView(query: searchText)
                            }
                        }
                        .opacity(isSearching ? 1 : 0)
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .onChange(of: searchText) { _, newValue in
                performSearch(query: newValue)
            }
            .onChange(of: selectedFilter) { _, _ in
                if isSearching {
                    performSearch(query: searchText)
                }
            }
        }
    }
    
    private func performSearch(query: String) {
        guard !query.isEmpty else {
            cachedSearchResults = []
            cachedItemResults = []
            cachedLocationResults = []
            return
        }
        
        var results: [SearchResultItem] = []
        
        // Get item results and filter if needed
        let itemResults = inventoryViewModel.searchItems(query: query)
        let filteredItems = applyFilter(to: itemResults)
        
        // Apply sorting to items based on selected sort option
        let sortedItems = sortItems(filteredItems, by: selectedSortOption)
        results.append(contentsOf: sortedItems.map { SearchResultItem.item($0) })
        
        // Add location results if not filtering by collection type
        if selectedFilter == .all {
            let locationResults = locationManager.searchLocations(query: query)
            results.append(contentsOf: locationResults.map { SearchResultItem.location($0) })
        }
        
        cachedSearchResults = results
        cachedItemResults = results.compactMap { result -> InventoryItem? in
            if case .item(let item) = result {
                return item
            }
            return nil
        }
        cachedLocationResults = results.compactMap { result -> StorageLocation? in
            if case .location(let location) = result {
                return location
            }
            return nil
        }
    }
    
    // Add filter helper method
    private func applyFilter(to items: [InventoryItem]) -> [InventoryItem] {
        switch selectedFilter {
        case .all:
            return items
        case .books:
            return items.filter { $0.type == .books }
        case .manga:
            return items.filter { $0.type == .manga }
        case .comics:
            return items.filter { $0.type == .comics }
        case .games:
            return items.filter { $0.type == .games }
        case .collectibles:
            return items.filter { $0.type == .collectibles }
        case .electronics:
            return items.filter { $0.type == .electronics }
        case .tools:
            return items.filter { $0.type == .tools }
        }
    }
    
    // Add sorting helper method
    private func sortItems(_ items: [InventoryItem], by sortOption: SortOption) -> [InventoryItem] {
        switch sortOption {
        case .relevance:
            // For relevance, use volume-aware sorting to fix numerical order
            return VolumeExtractor.sortInventoryItemsByVolume(items)
        case .titleAsc:
            // Use volume-aware sorting for ascending title order
            return VolumeExtractor.sortInventoryItemsByVolume(items)
        case .titleDesc:
            // Use volume-aware sorting then reverse for descending
            return VolumeExtractor.sortInventoryItemsByVolume(items).reversed()
        case .dateAddedNewest:
            return items.sorted { $0.dateAdded > $1.dateAdded }
        case .dateAddedOldest:
            return items.sorted { $0.dateAdded < $1.dateAdded }
        case .typeAsc:
            return items.sorted { $0.type.rawValue < $1.type.rawValue }
        case .typeDesc:
            return items.sorted { $0.type.rawValue > $1.type.rawValue }
        }
    }
}

// MARK: - Supporting Views

struct SearchResultsHeader: View {
    let resultCount: Int
    let sortOption: SortOption
    @Binding var showingSortOptions: Bool
    
    var body: some View {
        HStack {
            Text("\(resultCount) results")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: { showingSortOptions = true }) {
                HStack {
                    Text("Sort: \(sortOption.rawValue)")
                        .font(.subheadline)
                    Image(systemName: "arrow.up.arrow.down")
                }
                .foregroundColor(.primary)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal)
    }
}

struct SearchResultsList: View {
    let itemResults: [InventoryItem]
    let locationResults: [StorageLocation]
    
    var body: some View {
        List {
            if !locationResults.isEmpty {
                Section("Locations") {
                    ForEach(locationResults) { location in
                        NavigationLink(destination: LocationItemsView(location: location)) {
                            HStack {
                                Image(systemName: location.type.icon)
                                    .foregroundColor(.accentColor)
                                Text(location.name)
                            }
                        }
                    }
                }
            }
            
            if !itemResults.isEmpty {
                Section("Items") {
                    ForEach(itemResults) { item in
                        NavigationLink(destination: ItemDetailView(item: item)) {
                            ItemRow(item: item)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
} 