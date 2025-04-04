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
        print("🔄 MainView: Initializing with storage and location manager")
        let storage = StorageManager.shared
        let locationManager = LocationManager(storage: storage)
        _locationManager = StateObject(wrappedValue: locationManager)
        
        // Initialize inventory view model after location manager
        let inventoryVM = InventoryViewModel(storage: storage, locationManager: locationManager)
        print("🔄 MainView: Created inventory view model with \(inventoryVM.items.count) items")
        _inventoryViewModel = StateObject(wrappedValue: inventoryVM)
        
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
    @State private var showingQRScanner = false
    
    var body: some View {
        NavigationStack(path: $navigationCoordinator.path) {
            FixedSearchContainer()
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
}

#Preview {
    MainView()
}
