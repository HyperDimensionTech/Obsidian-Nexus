import SwiftUI

struct LocationsView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    @State private var showingAddLocation = false
    @State private var selectedLocation: StorageLocation?
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingAddItems = false
    @State private var expandedLocations: Set<UUID> = []
    @State private var errorMessage: String?
    @State private var showingError = false
    
    var body: some View {
        NavigationStack {
            List {
                LocationTreeView(
                    expandedLocations: $expandedLocations,
                    onLocationSelected: { location in
                        selectedLocation = location
                        showingAddItems = true
                    },
                    onEdit: { location in
                        selectedLocation = location
                        showingEditSheet = true
                    },
                    onDelete: { location in
                        selectedLocation = location
                        showingDeleteAlert = true
                    },
                    onShowQRCode: { location in
                        // Present QR code as a sheet instead of navigation
                        selectedLocation = location
                        showQRCodeForLocation(location)
                    }
                )
            }
            .navigationTitle("Locations")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        selectedLocation = nil
                        showingAddLocation = true
                    } label: {
                        Label("Add Location", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddLocation) {
                NavigationView {
                    AddLocationView(parentLocation: selectedLocation)
                        .environmentObject(locationManager)
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                if let location = selectedLocation {
                    NavigationView {
                        EditLocationView(location: location)
                            .environmentObject(locationManager)
                    }
                }
            }
            .sheet(isPresented: $showingAddItems) {
                if let location = selectedLocation {
                    NavigationView {
                        AddItemsToLocationView(locationId: location.id)
                            .environmentObject(locationManager)
                            .environmentObject(inventoryViewModel)
                            .environmentObject(navigationCoordinator)
                    }
                }
            }
            .alert("Delete Location", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let location = selectedLocation {
                        deleteLocation(location)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                if let location = selectedLocation {
                    Text("Are you sure you want to delete '\(location.name)' and all its contents?")
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                if let message = errorMessage {
                    Text(message)
                }
            }
            .onChange(of: selectedLocation) { oldValue, newValue in
                // Clear error when selection changes
                errorMessage = nil
            }
        }
        .onAppear {
            // Add notification observer when view appears
            NotificationCenter.default.addObserver(
                forName: Notification.Name("TabDoubleTapped"),
                object: nil,
                queue: .main
            ) { notification in
                // Only respond to locations tab double-taps
                if let tab = notification.object as? String, tab == "Locations" {
                    // Reset navigation when Locations tab is double-tapped
                    navigationCoordinator.navigateToRoot()
                }
            }
            
            // Add observer for deep links
            NotificationCenter.default.addObserver(
                forName: Notification.Name("LocationDeepLink"),
                object: nil,
                queue: .main
            ) { notification in
                if let userInfo = notification.userInfo,
                   let locationId = userInfo["locationId"] as? UUID,
                   let location = locationManager.getLocation(by: locationId) {
                    // Navigate to the location on the main thread
                    navigationCoordinator.navigate(to: .locationDetail(location))
                }
            }
        }
    }
    
    private func deleteLocation(_ location: StorageLocation) {
        do {
            try locationManager.removeLocation(location.id)
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    // Add this new function to handle QR code display
    private func showQRCodeForLocation(_ location: StorageLocation) {
        let qrCodeView = NavigationView {
            LocationQRCodeView(location: location)
        }
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            let hostingController = UIHostingController(rootView: qrCodeView)
            hostingController.modalPresentationStyle = .formSheet
            rootViewController.present(hostingController, animated: true)
        }
    }
}

#Preview {
    LocationsView()
        .environmentObject(PreviewData.shared.locationManager)
        .environmentObject(InventoryViewModel(locationManager: PreviewData.shared.locationManager))
        .environmentObject(NavigationCoordinator())
} 