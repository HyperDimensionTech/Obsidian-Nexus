import SwiftUI

struct LocationSettingsRow: View {
    @EnvironmentObject private var locationManager: LocationManager
    
    let location: StorageLocation
    @Binding var editingLocation: StorageLocation?
    @Binding var showingDeleteAlert: Bool
    @Binding var showingAddItems: Bool
    @Binding var selectedLocation: StorageLocation?
    @State private var showingMoveSheet = false
    @State private var showingRenameAlert = false
    @State private var newName = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        HStack {
            Image(systemName: location.type.icon)
                .foregroundColor(.accentColor)
            
            Text(location.name)
            
            Spacer()
            
            Menu {
                Button {
                    selectedLocation = location
                    showingAddItems = true
                } label: {
                    Label("Add Items", systemImage: "plus")
                }
                
                if location.type.category != .room {
                    Button {
                        showingMoveSheet = true
                    } label: {
                        Label("Move", systemImage: "arrow.right.square")
                    }
                }
                
                Button {
                    newName = location.name
                    showingRenameAlert = true
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                
                Button(role: .destructive) {
                    selectedLocation = location
                    showingDeleteAlert = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.secondary)
            }
        }
        .contentShape(Rectangle())
        .sheet(isPresented: $showingMoveSheet) {
            MoveLocationView(location: location)
        }
        .alert("Rename Location", isPresented: $showingRenameAlert) {
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) { }
            Button("Rename") {
                renameLocation()
            }
        } message: {
            Text("Enter a new name for \(location.name)")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func renameLocation() {
        do {
            try locationManager.renameLocation(location.id, to: newName)
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

#Preview {
    List {
        LocationSettingsRow(
            location: StorageLocation(name: "Sample Location", type: .room),
            editingLocation: .constant(nil),
            showingDeleteAlert: .constant(false),
            showingAddItems: .constant(false),
            selectedLocation: .constant(nil)
        )
        .environmentObject(PreviewData.shared.locationManager)
        .environmentObject(InventoryViewModel(locationManager: PreviewData.shared.locationManager))
    }
} 
