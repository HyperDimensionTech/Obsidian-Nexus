import SwiftUI

struct MainTabView: View {
    @StateObject private var locationManager: LocationManager
    @StateObject private var inventoryViewModel: InventoryViewModel
    @State private var showingAddItem = false
    @State private var selectedTab: Tab = .home
    
    init() {
        let storage = StorageManager.shared
        let locationManager = LocationManager(storage: storage)
        _locationManager = StateObject(wrappedValue: locationManager)
        _inventoryViewModel = StateObject(wrappedValue: 
            InventoryViewModel(storage: storage, locationManager: locationManager))
    }
    
    enum Tab {
        case home
        case collections
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
            
            CollectionsView()
                .tabItem {
                    Label("Collections", systemImage: "books")
                }
                .tag(Tab.collections)
            
            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
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
    }
}

#Preview {
    MainTabView()
        .environmentObject(PreviewData.shared.locationManager)
        .environmentObject(InventoryViewModel(locationManager: PreviewData.shared.locationManager))
} 