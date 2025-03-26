import SwiftUI

struct LocationTreeView: View {
    @EnvironmentObject var locationManager: LocationManager
    @Binding var expandedLocations: Set<UUID>
    let onLocationSelected: (StorageLocation) -> Void
    let onEdit: (StorageLocation) -> Void
    let onDelete: (StorageLocation) -> Void
    let onShowQRCode: (StorageLocation) -> Void
    
    var body: some View {
        ForEach(locationManager.rootLocations()) { location in
            LocationNode(
                location: location,
                expandedLocations: $expandedLocations,
                onLocationSelected: onLocationSelected,
                onEdit: onEdit,
                onDelete: onDelete,
                onShowQRCode: onShowQRCode
            )
        }
    }
}

struct LocationNode: View {
    @EnvironmentObject var locationManager: LocationManager
    let location: StorageLocation
    @Binding var expandedLocations: Set<UUID>
    let onLocationSelected: (StorageLocation) -> Void
    let onEdit: (StorageLocation) -> Void
    let onDelete: (StorageLocation) -> Void
    let onShowQRCode: (StorageLocation) -> Void
    
    private var isExpanded: Bool {
        expandedLocations.contains(location.id)
    }
    
    private var children: [StorageLocation] {
        locationManager.children(of: location.id)
    }
    
    var body: some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { isExpanded },
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
                LocationNode(
                    location: child,
                    expandedLocations: $expandedLocations,
                    onLocationSelected: onLocationSelected,
                    onEdit: onEdit,
                    onDelete: onDelete,
                    onShowQRCode: onShowQRCode
                )
                .padding(.leading)
            }
        } label: {
            HStack {
                Image(systemName: location.type.icon)
                    .foregroundColor(.accentColor)
                Text(location.name)
                Spacer()
                Menu {
                    if location.type.canHaveChildren {
                        Button {
                            onLocationSelected(location)
                        } label: {
                            Label("Add Item", systemImage: "plus")
                        }
                    }
                    Button {
                        onShowQRCode(location)
                    } label: {
                        Label("Show QR Code", systemImage: "qrcode")
                    }
                    Button {
                        onEdit(location)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        onDelete(location)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

// Keep as shared hierarchical display
// Used by both selection and management
// Maintains consistent tree visualization 

#Preview {
    NavigationView {
        LocationTreeView(
            expandedLocations: .constant([]),
            onLocationSelected: { _ in },
            onEdit: { _ in },
            onDelete: { _ in },
            onShowQRCode: { _ in }
        )
        .environmentObject(PreviewData.shared.locationManager)
    }
} 