import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var inventoryViewModel: InventoryViewModel
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    
    @State private var editingLocation: StorageLocation?
    @State private var showingDeleteAlert = false
    @State private var showingAddItems = false
    @State private var selectedLocation: StorageLocation?
    @State private var showingAddLocation = false
    @State private var expandedLocations: Set<UUID> = []
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("GENERAL")) {
                    NavigationLink("Account", destination: Text("Account Settings"))
                    NavigationLink("Notifications", destination: Text("Notification Settings"))
                    NavigationLink("Appearance", destination: Text("Appearance Settings"))
                }
                
                Section(header: 
                    HStack {
                        Text("LOCATIONS")
                        Spacer()
                        Button {
                            selectedLocation = nil
                            showingAddLocation = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                    }
                ) {
                    LocationTreeView(
                        expandedLocations: $expandedLocations,
                        onLocationSelected: { location in
                            selectedLocation = location
                            showingAddItems = true
                        },
                        onEdit: { location in
                            editingLocation = location
                        },
                        onDelete: { location in
                            selectedLocation = location
                            showingDeleteAlert = true
                        }
                    )
                }
                
                Section(header: Text("DATA")) {
                    NavigationLink("Import/Export", destination: Text("Import/Export"))
                    NavigationLink("Backup", destination: Text("Backup Settings"))
                }
            }
            .navigationTitle("Settings")
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
            .sheet(isPresented: $showingAddLocation) {
                NavigationView {
                    AddLocationView(parentLocation: selectedLocation)
                        .environmentObject(locationManager)
                }
            }
            .sheet(item: $editingLocation) { location in
                NavigationView {
                    EditLocationView(location: location)
                        .environmentObject(locationManager)
                }
            }
            .alert("Delete Location", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let location = selectedLocation {
                        try? locationManager.removeLocation(location.id)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                if let location = selectedLocation {
                    Text("Are you sure you want to delete '\(location.name)' and all its contents?")
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(LocationManager())
} 