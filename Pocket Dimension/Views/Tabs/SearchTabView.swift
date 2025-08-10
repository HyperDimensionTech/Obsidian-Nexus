import SwiftUI

struct SearchTabView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var locationManager: LocationManager
    @State private var showingQRScanner = false
    
    var body: some View {
        NavigationStack(path: navigationCoordinator.bindingForTab("Browse & Search")) {
            SearchView()
                .environmentObject(locationManager)
                .environmentObject(inventoryViewModel)
                .environmentObject(navigationCoordinator)
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
                    CollectionView(type: type)
                        .environmentObject(locationManager)
                        .environmentObject(inventoryViewModel)
                        .environmentObject(navigationCoordinator)
                }
                .navigationDestination(for: NavigationDestination.self) { destination in
                    switch destination {
                    case .itemDetail(let item):
                        ItemDetailView(item: item)
                            .environmentObject(locationManager)
                            .environmentObject(inventoryViewModel)
                            .environmentObject(navigationCoordinator)
                    case .locationDetail(let location):
                        LocationDetailView(location: location)
                            .environmentObject(locationManager)
                            .environmentObject(inventoryViewModel)
                            .environmentObject(navigationCoordinator)
                    case .locationItems(let location):
                        LocationItemsView(location: location)
                            .environmentObject(locationManager)
                            .environmentObject(inventoryViewModel)
                            .environmentObject(navigationCoordinator)
                    case .scannedLocation(let location):
                        LocationItemsView(location: location)
                            .environmentObject(locationManager)
                            .environmentObject(inventoryViewModel)
                            .environmentObject(navigationCoordinator)
                    case .seriesView(let type):
                        SeriesView(collectionType: type)
                            .environmentObject(locationManager)
                            .environmentObject(inventoryViewModel)
                            .environmentObject(navigationCoordinator)
                    case .seriesDetail(let seriesName, let collectionType):
                        SeriesDetailView(series: seriesName, collectionType: collectionType)
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
            // Set this as the active tab for navigation context
            navigationCoordinator.setActiveTab("Browse & Search")
            
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
        .environmentObject(LocationManager())
} 