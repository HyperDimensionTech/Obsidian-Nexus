import SwiftUI

struct CollectionsTabView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    var body: some View {
        NavigationStack(path: navigationCoordinator.bindingForTab("Collections")) {
            CollectionsView()
        }
        .onAppear {
            // Add notification observer when view appears
            NotificationCenter.default.addObserver(
                forName: Notification.Name("TabDoubleTapped"),
                object: nil,
                queue: .main
            ) { notification in
                // Only respond to collections tab double-taps
                if let tab = notification.object as? String, tab == "Collections" {
                    // Reset navigation when Collections tab is double-tapped
                    DispatchQueue.main.async {
                        navigationCoordinator.clearPathForTab("Collections")
                    }
                }
            }
        }
    }
}

#Preview {
    CollectionsTabView()
        .environmentObject(InventoryViewModel(locationManager: LocationManager()))
        .environmentObject(NavigationCoordinator())
} 