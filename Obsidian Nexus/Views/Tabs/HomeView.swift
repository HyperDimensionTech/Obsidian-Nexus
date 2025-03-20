import SwiftUI

struct HomeView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    var body: some View {
        NavigationStack(path: navigationCoordinator.bindingForTab("Home")) {
            DashboardView()
        }
        .onAppear {
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
} 