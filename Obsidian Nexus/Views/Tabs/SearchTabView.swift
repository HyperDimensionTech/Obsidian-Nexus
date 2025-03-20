import SwiftUI

struct SearchTabView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    var body: some View {
        NavigationStack(path: navigationCoordinator.bindingForTab("Browse & Search")) {
            SearchView()
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
                    // Reset navigation when Search tab is double-tapped
                    DispatchQueue.main.async {
                        navigationCoordinator.clearPathForTab("Browse & Search")
                    }
                }
            }
        }
    }
}

#Preview {
    SearchTabView()
        .environmentObject(InventoryViewModel(locationManager: LocationManager()))
        .environmentObject(NavigationCoordinator())
} 