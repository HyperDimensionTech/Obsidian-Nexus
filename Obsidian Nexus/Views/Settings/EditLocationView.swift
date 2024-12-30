import SwiftUI

struct EditLocationView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var locationManager: LocationManager
    
    let location: StorageLocation
    
    @State private var editedLocation: StorageLocation
    @State private var showingError = false
    @State private var errorMessage = ""
    
    init(location: StorageLocation) {
        self.location = location
        _editedLocation = State(initialValue: location)
    }
    
    var body: some View {
        Form {
            Section("Location Details") {
                TextField("Name", text: $editedLocation.name)
                
                LabeledContent("Type", value: location.type.name)
                
                if let parentId = location.parentId,
                   let parent = locationManager.location(withId: parentId) {
                    LabeledContent("Parent", value: parent.name)
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
    }
    
    private func saveLocation() {
        do {
            try locationManager.updateLocation(editedLocation)
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