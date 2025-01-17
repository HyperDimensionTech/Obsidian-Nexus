import SwiftUI

struct LocationPickerView: View {
    @EnvironmentObject var locationManager: LocationManager
    @Binding var selectedLocationId: UUID?
    
    var body: some View {
        List {
            Button("None") {
                selectedLocationId = nil
            }
            
            ForEach(locationManager.rootLocations()) { location in
                Section(location.name) {
                    // Show the room itself if it can contain items
                    if location.type.canContainItems {
                        LocationRow(
                            location: location,
                            isSelected: selectedLocationId == location.id,
                            hasChildren: !locationManager.children(of: location.id).isEmpty
                        ) {
                            selectedLocationId = location.id
                        }
                    }
                    
                    // Show children
                    ForEach(locationManager.children(of: location.id)) { child in
                        LocationRow(
                            location: child,
                            isSelected: selectedLocationId == child.id,
                            hasChildren: !locationManager.children(of: child.id).isEmpty
                        ) {
                            selectedLocationId = child.id
                        }
                        .padding(.leading)
                    }
                }
            }
        }
        .navigationTitle("Select Location")
    }
}

struct LocationRow: View {
    let location: StorageLocation
    let isSelected: Bool
    let hasChildren: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack {
                Image(systemName: location.type.icon)
                    .foregroundColor(.accentColor)
                
                Text(location.name)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
        }
    }
}

// Separate preview provider to ensure proper setup
struct LocationPickerView_Previews: PreviewProvider {
    static var previews: some View {
        let locationManager = LocationManager()
        locationManager.loadSampleData() // Load sample data before preview
        
        return NavigationView {
            LocationPickerView(selectedLocationId: .constant(nil))
                .environmentObject(locationManager)
        }
    }
} 