import SwiftUI

struct LocationTreeView: View {
    @EnvironmentObject var locationManager: LocationManager
    @Binding var expandedLocations: Set<UUID>
    let onLocationSelected: (StorageLocation) -> Void
    let onEdit: (StorageLocation) -> Void
    let onDelete: (StorageLocation) -> Void
    
    var body: some View {
        ForEach(locationManager.rootLocations()) { location in
            LocationTreeNode(
                location: location,
                depth: 0,
                expandedLocations: $expandedLocations,
                onLocationSelected: onLocationSelected,
                onEdit: onEdit,
                onDelete: onDelete
            )
        }
    }
}

struct LocationTreeNode: View {
    let location: StorageLocation
    let depth: Int
    @Binding var expandedLocations: Set<UUID>
    let onLocationSelected: (StorageLocation) -> Void
    let onEdit: (StorageLocation) -> Void
    let onDelete: (StorageLocation) -> Void
    @EnvironmentObject var locationManager: LocationManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: location.type.icon)
                    .foregroundColor(.accentColor)
                    .frame(width: 24)
                
                Text(location.name)
                    .font(.body)
                
                Spacer()
                
                if !locationManager.children(of: location.id).isEmpty {
                    Button {
                        withAnimation {
                            if expandedLocations.contains(location.id) {
                                expandedLocations.remove(location.id)
                            } else {
                                expandedLocations.insert(location.id)
                            }
                        }
                    } label: {
                        Image(systemName: expandedLocations.contains(location.id) ? "chevron.down" : "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                Menu {
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
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
            .padding(.leading, CGFloat(depth) * 20)
            .contentShape(Rectangle())
            .onTapGesture {
                onLocationSelected(location)
            }
            
            if expandedLocations.contains(location.id) {
                ForEach(locationManager.children(of: location.id)) { child in
                    LocationTreeNode(
                        location: child,
                        depth: depth + 1,
                        expandedLocations: $expandedLocations,
                        onLocationSelected: onLocationSelected,
                        onEdit: onEdit,
                        onDelete: onDelete
                    )
                }
            }
        }
    }
} 