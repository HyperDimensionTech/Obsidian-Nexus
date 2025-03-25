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
    @State private var selectedSortOption: SortOption = .titleAsc
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
                        // Safely handle state changes outside view update cycle
                        DispatchQueue.main.async {
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
                    }
                    
                // Filter bar below search
                SearchFilterBar(selectedFilter: $selectedFilter)
                    .onChange(of: selectedFilter) { _, _ in
                        // Re-run search when filter changes
                        if !searchText.isEmpty {
                            DispatchQueue.main.async {
                                performSearch(query: searchText)
                            }
                        }
                    }
                
                // Main content area
                if showingSearchResults {
                    // Show search results
                    if cachedSearchResults.isEmpty {
                        EmptySearchView(query: searchText)
                    } else {
                        VStack(spacing: 0) {
                            // Sort options bar
                            HStack {
                                Text("\(cachedSearchResults.count) results")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Button(action: {
                                    // Safely modify state outside of view update cycle
                                    DispatchQueue.main.async {
                                        showingSortOptions = true
                                    }
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
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            
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
                        .confirmationDialog("Sort By", isPresented: $showingSortOptions, titleVisibility: .visible) {
                            ForEach(SortOption.allCases) { option in
                                Button(option.rawValue) {
                                    DispatchQueue.main.async {
                                        selectedSortOption = option
                                        performSearch(query: searchText)
                                    }
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        // Safely modify state outside of view update cycle
                        DispatchQueue.main.async {
                            showingQRScanner = true
                        }
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
            ) { notification in
                // Only respond to search tab double-taps
                if let tab = notification.object as? String, tab == "Browse & Search" {
                    // Clear search when tab is double-tapped
                    DispatchQueue.main.async {
                        searchText = ""
                        selectedFilter = .all
                        showingSearchResults = false
                        
                        // Reset navigation
                        navigationCoordinator.navigateToRoot()
                    }
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
        let filteredItems = selectedFilter == .all ? 
            itemResults : 
            itemResults.filter { $0.type == selectedFilter.collectionType }
        
        // Apply sorting to items
        let sortedItems = selectedSortOption.sortItems(filteredItems)
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
}

// Empty search view
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

#Preview {
    MainView()
}
