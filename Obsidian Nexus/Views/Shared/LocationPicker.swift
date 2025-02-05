import SwiftUI

// Keep as base component for location selection
// Used by both item and settings views
// Maintains core selection functionality

struct LocationPicker: View {
    @EnvironmentObject var locationManager: LocationManager
    @Binding var selectedLocationId: UUID?
    @State private var expandedLocations: Set<UUID> = []
    
    var body: some View {
        List {
            Button("None") {
                selectedLocationId = nil
            }
            
            ForEach(locationManager.rootLocations()) { location in
                LocationPickerNode(location: location, selectedLocationId: $selectedLocationId, expandedLocations: $expandedLocations)
            }
        }
        .navigationTitle("Select Location")
    }
}

private struct LocationPickerNode: View {
    @EnvironmentObject var locationManager: LocationManager
    let location: StorageLocation
    @Binding var selectedLocationId: UUID?
    @Binding var expandedLocations: Set<UUID>
    
    var children: [StorageLocation] {
        locationManager.children(of: location.id)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    var body: some View {
        if !children.isEmpty {
            DisclosureGroup(
                isExpanded: Binding(
                    get: { expandedLocations.contains(location.id) },
                    set: { isExpanded in
                        if isExpanded {
                            expandedLocations.insert(location.id)
                        } else {
                            expandedLocations.remove(location.id)
                        }
                    }
                )
            ) {
                ForEach(children) { child in
                    LocationPickerNode(location: child, selectedLocationId: $selectedLocationId, expandedLocations: $expandedLocations)
                        .padding(.leading)
                }
            } label: {
                LocationPickerRow(location: location, selectedId: $selectedLocationId)
            }
        } else {
            LocationPickerRow(location: location, selectedId: $selectedLocationId)
        }
    }
}

struct LocationPickerRow: View {
    let location: StorageLocation
    @Binding var selectedId: UUID?
    
    var body: some View {
        Button {
            selectedId = location.id
        } label: {
            HStack {
                Image(systemName: location.type.icon)
                Text(location.name)
                Spacer()
                if selectedId == location.id {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        LocationPicker(selectedLocationId: .constant(nil))
            .environmentObject(PreviewData.shared.locationManager)
    }
} 