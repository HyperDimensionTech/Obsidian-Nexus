import SwiftUI

struct AddLocationView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var locationManager: LocationManager
    
    let parentLocation: StorageLocation?
    
    @State private var name = ""
    @State private var type: StorageLocation.LocationType = .room
    @State private var selectedLocationId: UUID?
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        Form {
            Section("Location Details") {
                TextField("Name", text: $name)
                
                LocationTypePickerView(
                    selectedType: $type,
                    parentLocation: parentLocation
                )
                
                if type.category != .room {
                    LocationPickerView(selectedLocationId: $selectedLocationId)
                        .onChange(of: selectedLocationId) { oldValue, newValue in
                            // Reset type if needed based on new parent
                            if let parentId = newValue,
                               let parent = locationManager.location(withId: parentId),
                               !parent.canAdd(childType: type) {
                                type = parent.type.allowedChildTypes.first ?? .room
                            }
                        }
                }
            }
            
            Section("Type Details") {
                LabeledContent {
                    Text(type.category.rawValue)
                } label: {
                    Text("Category")
                }
                
                LabeledContent {
                    Image(systemName: type.icon)
                } label: {
                    Text("Icon")
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
                .disabled(!canAdd)
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var canAdd: Bool {
        if name.isEmpty { return false }
        if type.category != .room && selectedLocationId == nil && parentLocation == nil {
            return false
        }
        return true
    }
    
    private func addLocation() {
        let newLocation = StorageLocation(
            name: name,
            type: type,
            parentId: parentLocation?.id ?? selectedLocationId
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