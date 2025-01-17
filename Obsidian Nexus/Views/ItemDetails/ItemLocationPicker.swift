import SwiftUI

struct ItemLocationPicker: View {
    @EnvironmentObject var locationManager: LocationManager
    @Binding var selectedLocationId: UUID?
    
    private var availableLocations: [StorageLocation] {
        // Only show locations that can contain items (furniture and containers)
        locationManager.allLocations().filter { location in
            location.type.category != .room // Show everything except rooms
        }.sorted { $0.name < $1.name }
    }
    
    var body: some View {
        Picker("Location", selection: $selectedLocationId) {
            Text("None")
                .tag(Optional<UUID>.none)
            
            ForEach(availableLocations) { location in
                HStack {
                    Image(systemName: location.type.icon)
                    Text(locationManager.path(to: location.id))
                }
                .tag(Optional(location.id))
            }
        }
        .pickerStyle(.navigationLink)
    }
}

#Preview {
    let locationManager = LocationManager()
    locationManager.loadSampleData()
    
    return Form {
        ItemLocationPicker(selectedLocationId: .constant(nil))
            .environmentObject(locationManager)
    }
} 