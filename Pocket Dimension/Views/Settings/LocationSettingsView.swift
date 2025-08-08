import SwiftUI

struct LocationSettingsView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var inventoryViewModel: InventoryViewModel
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    
    @State private var editingLocation: StorageLocation?
    @State private var showingDeleteAlert = false
    @State private var showingAddItems = false
    @State private var selectedLocation: StorageLocation?
    
    var body: some View {
        List {
            ForEach(locationManager.rootLocations()) { location in
                LocationSettingsRow(
                    location: location,
                    editingLocation: $editingLocation,
                    showingDeleteAlert: $showingDeleteAlert,
                    showingAddItems: $showingAddItems,
                    selectedLocation: $selectedLocation
                )
            }
        }
        .onChange(of: showingAddItems) { _, newValue in
            print("showingAddItems changed to: \(newValue)")
        }
        .sheet(isPresented: $showingAddItems) {
            Group {
                if let location = selectedLocation {
                    NavigationView {
                        AddItemsToLocationView(locationId: location.id)
                            .environmentObject(locationManager)
                            .environmentObject(inventoryViewModel)
                            .environmentObject(navigationCoordinator)
                    }
                }
            }
        }
        .sheet(item: $editingLocation) { location in
            NavigationView {
                EditLocationView(location: location)
            }
        }
        .alert("Delete Location", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                // Handle deletion
            }
            Button("Cancel", role: .cancel) { }
        }
    }
}

#Preview {
    NavigationView {
        LocationSettingsView()
            .environmentObject(PreviewData.shared.locationManager)
            .environmentObject(InventoryViewModel(locationManager: PreviewData.shared.locationManager))
            .environmentObject(NavigationCoordinator())
    }
} 