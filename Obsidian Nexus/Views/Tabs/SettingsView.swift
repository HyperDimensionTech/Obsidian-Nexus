import SwiftUI
import Combine

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
        NavigationStack(path: $navigationCoordinator.path) {
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
                
                // Temporarily hide DATA MANAGEMENT section
                // Section(header: Text("DATA MANAGEMENT")) { ... }
                
                Section(header: Text("DATA")) {
                    NavigationLink("Import/Export", destination: Text("Import/Export"))
                    NavigationLink("Backup", destination: Text("Backup Settings"))
                }
                
                Section(header: Text("ADVANCED")) {
                    NavigationLink(destination: ISBNMappingsView()) {
                        HStack {
                            Image(systemName: "barcode")
                                .foregroundColor(.accentColor)
                                .frame(width: 24)
                            Text("ISBN Mappings")
                        }
                    }
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
        .onAppear {
            // Add notification observer when view appears
            NotificationCenter.default.addObserver(
                forName: Notification.Name("TabDoubleTapped"),
                object: nil,
                queue: .main
            ) { notification in
                // Only respond to settings tab double-taps
                if let tab = notification.object as? String, tab == "Settings" {
                    // Reset navigation when Settings tab is double-tapped
                    // Use DispatchQueue.main to ensure we're on the main thread
                    DispatchQueue.main.async {
                        navigationCoordinator.navigateToRoot()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(LocationManager())
        .environmentObject(InventoryViewModel(locationManager: LocationManager()))
        .environmentObject(NavigationCoordinator())
}

private struct TrashSection: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @State private var showingEmptyTrashAlert = false
    
    var body: some View {
        List {
            if inventoryViewModel.trashedItems.isEmpty {
                Text("No items in trash")
                    .foregroundColor(.secondary)
            } else {
                ForEach(inventoryViewModel.trashedItems) { item in
                    ItemRow(item: item)
                        .swipeActions {
                            Button("Restore") {
                                try? inventoryViewModel.restoreItem(item)
                            }
                            .tint(.blue)
                        }
                }
            }
        }
        .navigationTitle("Trash")
        .toolbar {
            if !inventoryViewModel.trashedItems.isEmpty {
                Button("Empty Trash", role: .destructive) {
                    showingEmptyTrashAlert = true
                }
            }
        }
        .alert("Empty Trash?", isPresented: $showingEmptyTrashAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Empty", role: .destructive) {
                try? inventoryViewModel.emptyTrash()
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .onAppear {
            inventoryViewModel.loadTrashedItems()
        }
    }
} 