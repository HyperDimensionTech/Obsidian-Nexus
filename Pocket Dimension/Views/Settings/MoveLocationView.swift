import SwiftUI

struct MoveLocationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var locationManager: LocationManager
    
    let location: StorageLocation
    @State private var selectedParentId: UUID?
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var validParentLocations: [StorageLocation] {
        locationManager.allLocations().filter { potentialParent in
            // Can't move to itself or its descendants
            guard potentialParent.id != location.id else { return false }
            let descendants = locationManager.descendants(of: location.id)
            guard !descendants.contains(potentialParent) else { return false }
            
            // Must be able to contain this type
            return potentialParent.canAdd(childType: location.type)
        }
    }
    
    var body: some View {
        NavigationView {
            List(validParentLocations) { parentLocation in
                Button {
                    moveLocation(to: parentLocation)
                } label: {
                    HStack {
                        Image(systemName: parentLocation.type.icon)
                            .foregroundColor(.accentColor)
                        Text(parentLocation.name)
                        Spacer()
                        if location.parentId == parentLocation.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Move \(location.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func moveLocation(to newParent: StorageLocation) {
        do {
            try locationManager.migrateLocation(location.id, to: newParent.id)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

#Preview {
    MoveLocationView(location: StorageLocation(name: "Test Box", type: .box))
        .environmentObject(LocationManager())
} 