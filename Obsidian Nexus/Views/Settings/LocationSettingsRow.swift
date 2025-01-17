import SwiftUI

struct LocationSettingsRow: View {
    @EnvironmentObject private var locationManager: LocationManager
    
    let location: StorageLocation
    @Binding var editingLocation: StorageLocation?
    @Binding var showingDeleteAlert: Bool
    @Binding var showingAddItems: Bool
    @Binding var selectedLocation: StorageLocation?
    
    var body: some View {
        HStack {
            Image(systemName: location.type.icon)
                .foregroundColor(.accentColor)
            
            Text(location.name)
            
            Spacer()
            
            Menu {
                Button {
                    print("Add Items button clicked")
                    print("Location: \(location.name)")
                    selectedLocation = location
                    print("Selected Location set to: \(String(describing: selectedLocation?.name))")
                    showingAddItems = true
                    print("showingAddItems set to: \(showingAddItems)")
                } label: {
                    Label("Add Items", systemImage: "plus")
                }
                
                Button {
                    editingLocation = location
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                
                Button(role: .destructive) {
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
    }
} 
