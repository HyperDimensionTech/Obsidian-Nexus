import SwiftUI

struct LocationPickerView: View {
    @EnvironmentObject var locationManager: LocationManager
    @Binding var selectedLocationId: UUID?
    
    var body: some View {
        Picker("Location", selection: $selectedLocationId) {
            Text("None")
                .tag(Optional<UUID>.none)
            
            ForEach(locationManager.allLocations(), id: \.id) { location in
                Text(locationManager.path(to: location.id))
                    .tag(Optional(location.id))
            }
        }
        .pickerStyle(.navigationLink)
    }
}

#Preview {
    let locationManager = LocationManager()
    return NavigationView {
        Form {
            LocationPickerView(selectedLocationId: .constant(nil))
                .environmentObject(locationManager)
        }
    }
} 