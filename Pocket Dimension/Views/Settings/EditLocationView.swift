import SwiftUI

struct EditLocationView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var locationManager: LocationManager
    
    let location: StorageLocation
    @State private var editedLocation: StorageLocation
    @State private var selectedParentId: UUID?
    @State private var showingError = false
    @State private var errorMessage = ""
    
    init(location: StorageLocation) {
        self.location = location
        _editedLocation = State(initialValue: location)
        _selectedParentId = State(initialValue: location.parentId)
    }
    
    private var availableParents: [StorageLocation] {
        // Filter out the location itself and its descendants to prevent circular references
        locationManager.allLocations().filter { possibleParent in
            // Don't include self or descendants
            possibleParent.id != location.id &&
            !locationManager.descendants(of: location.id).contains(possibleParent) &&
            // Must be able to contain this type of location
            possibleParent.type.allowedChildTypes.contains(location.type)
        }
    }
    
    var body: some View {
        Form {
            Section("Location Details") {
                TextField("Name", text: $editedLocation.name)
                
                LocationTypePickerView(
                    selectedType: Binding(
                        get: { self.editedLocation.type },
                        set: { self.editedLocation.type = $0 }
                    ),
                    parentLocation: locationManager.location(withId: editedLocation.parentId ?? UUID())
                )
                .disabled(true)
                
                if location.type.category != .room {
                    Picker("Parent Location", selection: $selectedParentId) {
                        Text("None").tag(Optional<UUID>.none)
                        ForEach(availableParents) { parent in
                            Text(parent.name).tag(Optional(parent.id))
                        }
                    }
                }
            }
            
            Section("Type Details") {
                LabeledContent {
                    Text(location.type.category.rawValue)
                } label: {
                    Text("Category")
                }
                
                LabeledContent {
                    Image(systemName: location.type.icon)
                } label: {
                    Text("Icon")
                }
                
                if location.type.canHaveChildren {
                    LabeledContent {
                        Text("Can contain \(location.type.allowedChildTypes.map { $0.name }.joined(separator: ", "))")
                            .font(.caption)
                    } label: {
                        Text("Storage")
                    }
                }
            }
            
            if !location.childIds.isEmpty {
                Section("Contents") {
                    ForEach(locationManager.children(of: location.id)) { child in
                        Label {
                            Text(child.name)
                        } icon: {
                            Image(systemName: child.type.icon)
                        }
                    }
                }
            }
        }
        .navigationTitle("Edit Location")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveLocation()
                }
                .disabled(editedLocation.name.isEmpty)
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onChange(of: selectedParentId) { oldValue, newValue in
            var updated = editedLocation
            updated.parentId = newValue
            editedLocation = updated
        }
    }
    
    private func saveLocation() {
        var locationToSave = editedLocation
        locationToSave.parentId = selectedParentId
        
        do {
            try locationManager.updateLocation(locationToSave)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

#Preview {
    let sampleLocation = StorageLocation(
        name: "Living Room",
        type: .room
    )
    
    NavigationView {
        EditLocationView(location: sampleLocation)
            .environmentObject(LocationManager())
    }
} 