import SwiftUI

struct LocationsView: View {
    @EnvironmentObject var locationManager: LocationManager
    @State private var showingAddLocation = false
    @State private var selectedLocation: StorageLocation?
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var expandedLocations: Set<UUID> = []
    @State private var errorMessage: String?
    @State private var showingError = false
    
    var body: some View {
        List {
            LocationTreeView(
                expandedLocations: $expandedLocations,
                onLocationSelected: { location in
                    // Handle selection if needed
                },
                onEdit: { location in
                    selectedLocation = location
                    showingEditSheet = true
                },
                onDelete: { location in
                    selectedLocation = location
                    showingDeleteAlert = true
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
    
    private func deleteLocation(_ location: StorageLocation) {
        do {
            try locationManager.removeLocation(location.id)
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

#Preview {
    NavigationView {
        LocationsView()
            .environmentObject(LocationManager())
    }
} 