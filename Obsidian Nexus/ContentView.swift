//
//  ContentView.swift
//  Obsidian Nexus
//
//  Created by Andrew Palmer on 12/30/24.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var locationManager: LocationManager
    @StateObject private var inventoryViewModel: InventoryViewModel
    @StateObject private var navigationCoordinator = NavigationCoordinator()
    @State private var selectedTab = 0
    @State private var previousTab = 0
    
    init() {
        let storage = StorageManager.shared
        let locationManager = LocationManager(storage: storage)
        _locationManager = StateObject(wrappedValue: locationManager)
        _inventoryViewModel = StateObject(wrappedValue: 
            InventoryViewModel(storage: storage, locationManager: locationManager))
    }
    
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
            
            AddItemTabView()
                .tabItem {
                    Label("Add", systemImage: "plus.circle.fill")
                }
                .tag(2)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
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
        .environmentObject(locationManager)
        .environmentObject(inventoryViewModel)
        .environmentObject(navigationCoordinator)
    }
    
    // Helper function to get tab name from index
    private func getTabName(for tabIndex: Int) -> String {
        switch tabIndex {
        case 0: return "Home"
        case 1: return "Browse & Search"
        case 2: return "Add"
        case 3: return "Settings"
        default: return ""
        }
    }
}

// New combined tab view
struct CombinedSearchTabView: View {
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
                    // Clear search when tab is double-tapped
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
    ContentView()
        .environmentObject(PreviewData.shared.locationManager)
        .environmentObject(InventoryViewModel(locationManager: PreviewData.shared.locationManager))
}
