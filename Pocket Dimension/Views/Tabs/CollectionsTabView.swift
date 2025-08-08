import SwiftUI

struct CollectionsTabView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @State private var notificationObserver: NSObjectProtocol?
    
    var body: some View {
        NavigationStack(path: navigationCoordinator.bindingForTab("Collections")) {
            CollectionsView()
        }
        .onAppear {
            // Add notification observer when view appears
            notificationObserver = NotificationCenter.default.addObserver(
                forName: Notification.Name("TabDoubleTapped"),
                object: nil,
                queue: .main
            ) { [weak navigationCoordinator] notification in
                // Only respond to collections tab double-taps
                if let tab = notification.object as? String, tab == "Collections" {
                    // Reset navigation when Collections tab is double-tapped
                    DispatchQueue.main.async {
                        navigationCoordinator?.clearPathForTab("Collections")
                    }
                }
            }
        }
        .onDisappear {
            // Clean up notification observer
            if let observer = notificationObserver {
                NotificationCenter.default.removeObserver(observer)
                notificationObserver = nil
            }
        }
    }
}

#Preview {
    CollectionsTabView()
        .environmentObject(InventoryViewModel(locationManager: LocationManager()))
        .environmentObject(NavigationCoordinator())
} 