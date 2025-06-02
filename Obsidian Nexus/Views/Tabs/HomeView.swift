import SwiftUI

struct HomeView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var locationManager: LocationManager
    
    var body: some View {
        NavigationStack(path: navigationCoordinator.bindingForTab("Home")) {
            DashboardView()
                .navigationDestination(for: NavigationDestination.self) { destination in
                    switch destination {
                    case .seriesDetail(let seriesName, let collectionType):
                        SeriesDetailView(series: seriesName, collectionType: collectionType)
                            .environmentObject(locationManager)
                            .environmentObject(inventoryViewModel)
                            .environmentObject(navigationCoordinator)
                    case .itemDetail(let item):
                        ItemDetailView(item: item)
                            .environmentObject(locationManager)
                            .environmentObject(inventoryViewModel)
                            .environmentObject(navigationCoordinator)
                    default:
                        EmptyView()
                    }
                }
        }
        .onAppear {
            // Set this as the active tab for navigation context
            navigationCoordinator.setActiveTab("Home")
            
            // Add notification observer when view appears
            NotificationCenter.default.addObserver(
                forName: Notification.Name("TabDoubleTapped"),
                object: nil,
                queue: .main
            ) { notification in
                // Only respond to home tab double-taps
                if let tab = notification.object as? String, tab == "Home" {
                    // Reset navigation when Home tab is double-tapped
                    // Use DispatchQueue.main to ensure we're on the main thread
                    DispatchQueue.main.async {
                        navigationCoordinator.clearPathForTab("Home")
                    }
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(InventoryViewModel(locationManager: LocationManager()))
        .environmentObject(NavigationCoordinator())
        .environmentObject(LocationManager())
} 