import SwiftUI

struct MainTabView: View {
    @StateObject private var locationManager: LocationManager
    @StateObject private var inventoryViewModel: InventoryViewModel
    @StateObject private var navigationCoordinator = NavigationCoordinator()
    @State private var showingAddItem = false
    @State private var selectedTab: Tab = .home
    @State private var previousTab: Tab = .home
    
    init() {
        let storage = StorageManager.shared
        let locationManager = LocationManager(storage: storage)
        _locationManager = StateObject(wrappedValue: locationManager)
        _inventoryViewModel = StateObject(wrappedValue: 
            InventoryViewModel(storage: storage, locationManager: locationManager))
    }
    
    enum Tab {
        case home
        case search
        case add
        case settings
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .environmentObject(locationManager)
                .environmentObject(inventoryViewModel)
                .environmentObject(navigationCoordinator)
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(Tab.home)
            
            SearchTabView()
                .environmentObject(locationManager)
                .environmentObject(inventoryViewModel)
                .environmentObject(navigationCoordinator)
                .tabItem {
                    Label("Browse & Search", systemImage: "magnifyingglass")
                }
                .tag(Tab.search)
            
            Text("")
                .tabItem {
                    Label("Add", systemImage: "plus.circle.fill")
                }
                .tag(Tab.add)
            
            SettingsView()
                .environmentObject(locationManager)
                .environmentObject(inventoryViewModel)
                .environmentObject(navigationCoordinator)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(Tab.settings)
        }
        .onChange(of: selectedTab) { oldTab, newTab in
            if newTab == .add {
                selectedTab = oldTab
                showingAddItem = true
            } else {
                // Handle tab changes for navigation
                handleTabSelection(oldTab: oldTab, newTab: newTab)
            }
        }
        .sheet(isPresented: $showingAddItem) {
            NavigationView {
                AddItemView()
                    .environmentObject(locationManager)
                    .environmentObject(inventoryViewModel)
            }
        }
        .onAppear {
            // Setup deep link handler
            NotificationCenter.default.addObserver(
                forName: Notification.Name("LocationDeepLink"),
                object: nil,
                queue: .main
            ) { notification in
                if let userInfo = notification.userInfo,
                   let locationId = userInfo["locationId"] as? UUID,
                   let location = locationManager.getLocation(by: locationId) {
                    // Switch to search tab for location viewing
                    selectedTab = .search
                    // Navigate to location items view
                    navigationCoordinator.navigate(to: .scannedLocation(location))
                }
            }
        }
    }
    
    private func handleTabSelection(oldTab: Tab, newTab: Tab) {
        // Clear navigation path of the old tab when switching
        switch oldTab {
        case .home:
            navigationCoordinator.clearPathForTab("Home")
        case .search:
            navigationCoordinator.clearPathForTab("Browse & Search")
        case .settings:
            navigationCoordinator.clearPathForTab("Settings")
        case .add:
            // Clear any navigation state from add view
            navigationCoordinator.navigateToRoot()
        }
        
        // Also clear the Collections path if we were in it
        if navigationCoordinator.pathForTab("Collections").count > 0 {
            navigationCoordinator.clearPathForTab("Collections")
        }
        
        // If tapping the same tab again
        if newTab == previousTab {
            // Post a notification that can be observed by any view to reset its state
            NotificationCenter.default.post(
                name: Notification.Name("TabDoubleTapped"),
                object: getTabStringName(newTab)
            )
            
            // Trigger haptic feedback for double tap
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
        
        // Update previous tab
        previousTab = newTab
    }
    
    private func getTabStringName(_ tab: Tab) -> String {
        switch tab {
        case .home: return "Home"
        case .search: return "Browse & Search"
        case .settings: return "Settings"
        case .add: return "Add"
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(PreviewData.shared.locationManager)
        .environmentObject(InventoryViewModel(locationManager: PreviewData.shared.locationManager))
} 