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
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(Tab.home)
            
            SearchView()
                .tabItem {
                    Label("Browse & Search", systemImage: "magnifyingglass")
                }
                .tag(Tab.search)
            
            Button {
                showingAddItem = true
            } label: {
                Label("Add", systemImage: "plus")
            }
            .tabItem {
                Label("Add", systemImage: "plus")
            }
            .tag(Tab.add)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(Tab.settings)
        }
        .onChange(of: selectedTab) { oldTab, newTab in
            handleTabSelection(oldTab: oldTab, newTab: newTab)
        }
        .sheet(isPresented: $showingAddItem) {
            NavigationView {
                AddItemView()
                    .navigationBarTitleDisplayMode(.inline)
                    .interactiveDismissDisabled()
            }
            .presentationDragIndicator(.visible)
        }
        .environmentObject(locationManager)
        .environmentObject(inventoryViewModel)
        .environmentObject(navigationCoordinator)
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
                object: newTab
            )
            
            // Trigger haptic feedback for double tap
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
        
        // Update previous tab
        previousTab = newTab
    }
}

#Preview {
    MainTabView()
        .environmentObject(PreviewData.shared.locationManager)
        .environmentObject(InventoryViewModel(locationManager: PreviewData.shared.locationManager))
} 