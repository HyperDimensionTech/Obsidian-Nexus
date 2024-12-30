import SwiftUI

struct AddLocationView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var locationManager: LocationManager
    
    let parentLocation: StorageLocation?
    
    @State private var name = ""
    @State private var type: StorageLocation.LocationType = .room
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private var allowedTypes: [StorageLocation.LocationType] {
        if let parent = parentLocation {
            return parent.type.allowedChildTypes
        }
        return [.room] // Only rooms can be root locations
    }
    
    init(parentLocation: StorageLocation? = nil) {
        self.parentLocation = parentLocation
        // Set initial type based on parent
        if let parent = parentLocation {
            _type = State(initialValue: parent.type.allowedChildTypes.first ?? .room)
        } else {
            _type = State(initialValue: .room)
        }
    }
    
    var body: some View {
        Form {
            Section("Location Details") {
                TextField("Name", text: $name)
                
                Picker("Type", selection: $type) {
                    ForEach(allowedTypes) { type in
                        Text(type.name)
                            .tag(type)
                    }
                }
                .onChange(of: parentLocation) { oldValue, newValue in
                    // Reset type to first allowed type when parent changes
                    if let firstAllowed = allowedTypes.first {
                        type = firstAllowed
                    }
                }
                
                if let parent = parentLocation {
                    LabeledContent("Parent", value: parent.name)
                }
            }
        }
        .navigationTitle("Add Location")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    addLocation()
                }
                .disabled(name.isEmpty)
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func addLocation() {
        let newLocation = StorageLocation(
            name: name,
            type: type,
            parentId: parentLocation?.id
        )
        
        do {
            try locationManager.addLocation(newLocation)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

#Preview {
    NavigationView {
        AddLocationView(parentLocation: nil)
            .environmentObject(LocationManager())
    }
} 