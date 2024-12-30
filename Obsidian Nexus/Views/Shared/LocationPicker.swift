import SwiftUI

struct LocationPicker: View {
    @EnvironmentObject var locationManager: LocationManager
    @Binding var selectedLocationId: UUID?
    
    var body: some View {
        List {
            Button("None") {
                selectedLocationId = nil
            }
            
            ForEach(locationManager.locations(ofType: .room)) { room in
                Section(room.name) {
                    LocationPickerRow(location: room, selectedId: $selectedLocationId)
                    
                    ForEach(locationManager.children(of: room.id)) { child in
                        LocationPickerRow(location: child, selectedId: $selectedLocationId)
                            .padding(.leading)
                    }
                }
            }
        }
        .navigationTitle("Select Location")
    }
}

struct LocationPickerRow: View {
    let location: StorageLocation
    @Binding var selectedId: UUID?
    
    var body: some View {
        Button {
            selectedId = location.id
        } label: {
            HStack {
                Image(systemName: location.type.icon)
                Text(location.name)
                Spacer()
                if selectedId == location.id {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        LocationPicker(selectedLocationId: .constant(nil))
            .environmentObject(LocationManager())
    }
} 