//
//  ContentView.swift
//  Obsidian Nexus
//
//  Created by Andrew Palmer on 12/30/24.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var previousTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(0)
            
            // Combined Browse & Search tab
            CombinedSearchTabView()
                .tabItem {
                    Label("Browse & Search", systemImage: "magnifyingglass")
                }
                .tag(1)
            
            // Locations tab
            LocationsView()
                .tabItem {
                    Label("Locations", systemImage: "folder")
                }
                .tag(2)
            
            AddItemTabView()
                .tabItem {
                    Label("Add", systemImage: "plus.circle.fill")
                }
                .tag(3)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(4)
        }
        .onChange(of: selectedTab) { oldTab, newTab in
            // If tapping the same tab again
            if newTab == previousTab {
                // Post a notification that can be observed by any view to reset its state
                NotificationCenter.default.post(
                    name: Notification.Name("TabDoubleTapped"),
                    object: getTabName(for: newTab)
                )
                
                // Trigger haptic feedback for double tap
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
            
            // Update previous tab
            previousTab = newTab
        }
    }
    
    // Helper function to get tab name from index
    private func getTabName(for tabIndex: Int) -> String {
        switch tabIndex {
        case 0: return "Home"
        case 1: return "Browse & Search"
        case 2: return "Locations"
        case 3: return "Add"
        case 4: return "Settings"
        default: return ""
        }
    }
}

struct MainView: View {
    @StateObject private var locationManager: LocationManager
    @StateObject private var inventoryViewModel: InventoryViewModel
    @StateObject private var navigationCoordinator = NavigationCoordinator()
    @StateObject private var userPreferences = UserPreferences()
    @StateObject private var scanResultManager = ScanResultManager()
    @StateObject private var serviceContainer = ServiceContainer.shared
    
    init() {
        let storage = StorageManager.shared
        let locationManager = LocationManager(storage: storage)
        _locationManager = StateObject(wrappedValue: locationManager)
        _inventoryViewModel = StateObject(wrappedValue: 
            InventoryViewModel(storage: storage, locationManager: locationManager))
        
        // Initialize the CurrencyManager singleton to ensure it's ready to handle currency changes
        _ = CurrencyManager.shared
    }
    
    var body: some View {
        ContentView()
            .environmentObject(locationManager)
            .environmentObject(inventoryViewModel)
            .environmentObject(navigationCoordinator)
            .environmentObject(userPreferences)
            .environmentObject(scanResultManager)
            .environmentObject(serviceContainer)
             .preferredColorScheme(userPreferences.theme.colorScheme)
    }
}

// New combined tab view
struct CombinedSearchTabView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var locationManager: LocationManager
    @State private var searchText = ""
    @State private var selectedFilter: SearchFilter = .all
    @State private var showingSearchResults = false
    @State private var selectedSortOption: SortOption = .relevance
    @State private var showingSortOptions = false
    @State private var showingQRScanner = false
    
    // Store results in state variables instead of computed properties
    @State private var cachedSearchResults: [SearchResultItem] = []
    @State private var cachedItemResults: [InventoryItem] = []
    @State private var cachedLocationResults: [StorageLocation] = []
    
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
    
    var body: some View {
        NavigationStack(path: $navigationCoordinator.path) {
            VStack(spacing: 0) {
                // Search bar at the top
                SearchBar(text: $searchText)
                    .padding()
                    .onChange(of: searchText) { _, newValue in
                        showingSearchResults = !newValue.isEmpty
                        if !newValue.isEmpty {
                            performSearch(query: newValue)
                        } else {
                            // Clear results when search is empty
                            cachedSearchResults = []
                            cachedItemResults = []
                            cachedLocationResults = []
                        }
                    }
                    
                // Filter bar below search
                SearchFilterBar(selectedFilter: $selectedFilter)
                    .onChange(of: selectedFilter) { _, _ in
                        // Re-run search when filter changes
                        if !searchText.isEmpty {
                            performSearch(query: searchText)
                        }
                    }
                
                // Main content area
                if showingSearchResults {
                    // Show search results with consistent layout structure
                    VStack(spacing: 0) {
                        // Sort options bar (always show for consistency)
                        HStack {
                            Text("\(cachedSearchResults.count) results")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            if !cachedSearchResults.isEmpty {
                                Button(action: {
                                    showingSortOptions = true
                                }) {
                                    HStack {
                                        Text("Sort: \(selectedSortOption.rawValue)")
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
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        
                        // Results content
                        if cachedSearchResults.isEmpty {
                            // Wrap empty view in a List to match the layout structure of results
                            List {
                                Section {
                                    VStack(spacing: 16) {
                                        Image(systemName: "magnifyingglass")
                                            .font(.system(size: 48))
                                            .foregroundColor(.secondary)
                                        Text("No results found for \"\(searchText)\"")
                                            .font(.headline)
                                        Text("Try adjusting your search terms")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                                    .listRowBackground(Color.clear)
                                }
                            }
                            .listStyle(.insetGrouped)
                        } else {
                            // Results list
                            List {
                                // Show locations section
                                if !cachedLocationResults.isEmpty {
                                    Section("Locations") {
                                        ForEach(cachedLocationResults) { location in
                                            NavigationLink(destination: LocationItemsView(location: location)
                                                .environmentObject(locationManager)
                                                .environmentObject(inventoryViewModel)
                                                .environmentObject(navigationCoordinator)
                                            ) {
                                                HStack {
                                                    Image(systemName: location.type.icon)
                                                        .foregroundColor(.accentColor)
                                                    Text(location.name)
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                // Show items section
                                if !cachedItemResults.isEmpty {
                                    Section("Items") {
                                        ForEach(cachedItemResults) { item in
                                            NavigationLink(destination: ItemDetailView(item: item)
                                                .environmentObject(locationManager)
                                                .environmentObject(inventoryViewModel)
                                                .environmentObject(navigationCoordinator)
                                            ) {
                                                ItemRow(item: item)
                                            }
                                        }
                                    }
                                }
                            }
                            .listStyle(.insetGrouped)
                        }
                    }
                    .confirmationDialog("Sort By", isPresented: $showingSortOptions, titleVisibility: .visible) {
                        ForEach(SortOption.allCases) { option in
                            Button(option.rawValue) {
                                selectedSortOption = option
                                performSearch(query: searchText)
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    }
                } else {
                    // Show collections grid when not searching
                    FixedSearchContainer(showSearchBar: false)
                }
            }
            .navigationTitle("Browse & Search")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        showingQRScanner = true
                    }) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 18))
                    }
                }
            }
            .navigationDestination(for: CollectionType.self) { type in
                CollectionDetailView(type: type)
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .scannedLocation(let location):
                    LocationItemsView(location: location)
                        .environmentObject(locationManager)
                        .environmentObject(inventoryViewModel)
                        .environmentObject(navigationCoordinator)
                default:
                    EmptyView()
                }
            }
        }
        .sheet(isPresented: $showingQRScanner) {
            NavigationView {
                LocationQRScannerView()
                    .environmentObject(locationManager)
                    .environmentObject(navigationCoordinator)
            }
        }
        .onAppear {
            // Add notification observer when view appears
            NotificationCenter.default.addObserver(
                forName: Notification.Name("TabDoubleTapped"),
                object: nil,
                queue: .main
            ) { [weak navigationCoordinator] notification in
                // Only respond to search tab double-taps
                if let tab = notification.object as? String, tab == "Browse & Search" {
                    // Reset navigation when Search tab is double-tapped
                    Task { @MainActor [weak navigationCoordinator] in
                        navigationCoordinator?.navigateToRoot()
                    }
                }
            }
        }
    }
    
    // MARK: - Search Functions
    private func performSearch(query: String) {
        guard !query.isEmpty else { return }
        
        // Search items
        let itemResults = inventoryViewModel.searchItems(query: query)
        
        // Search locations
        let locationResults = locationManager.searchLocations(query: query)
        
        // Apply filter
        let filteredItems = applyFilter(to: itemResults)
        let filteredLocations = applyLocationFilter(to: locationResults)
        
        // Sort results
        let sortedItems = sortItems(filteredItems)
        let sortedLocations = sortLocations(filteredLocations)
        
        // Update state
        cachedItemResults = sortedItems
        cachedLocationResults = sortedLocations
        
        // Combine results
        cachedSearchResults = sortedItems.map { .item($0) } + sortedLocations.map { .location($0) }
    }
    
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
    
    private func applyLocationFilter(to locations: [StorageLocation]) -> [StorageLocation] {
        // For now, locations don't have type filtering
        return locations
    }
    
    private func sortItems(_ items: [InventoryItem]) -> [InventoryItem] {
        switch selectedSortOption {
        case .relevance:
            // Don't re-sort relevance results - they're already sorted by score from the search
            return items
        case .titleAsc:
            return items.sorted { $0.title < $1.title }
        case .titleDesc:
            return items.sorted { $0.title > $1.title }
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
    
    private func sortLocations(_ locations: [StorageLocation]) -> [StorageLocation] {
        return locations.sorted { $0.name < $1.name }
    }
}

// Supporting enums
enum SearchFilter: String, CaseIterable {
    case all = "All"
    case books = "Books"
    case manga = "Manga"
    case comics = "Comics"
    case games = "Games"
    case collectibles = "Collectibles"
    case electronics = "Electronics"
    case tools = "Tools"
}

enum SortOption: String, CaseIterable, Identifiable {
    case relevance = "Relevance"
    case titleAsc = "Title A-Z"
    case titleDesc = "Title Z-A"
    case dateAddedNewest = "Newest"
    case dateAddedOldest = "Oldest"
    case typeAsc = "Type A-Z"
    case typeDesc = "Type Z-A"
    
    var id: String { rawValue }
}

#Preview {
    MainView()
}
