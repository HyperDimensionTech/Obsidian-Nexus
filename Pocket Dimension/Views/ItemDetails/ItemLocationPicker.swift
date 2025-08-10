import SwiftUI

struct ItemLocationPicker: View {
    @EnvironmentObject var locationManager: LocationManager
    @Binding var selectedLocationId: UUID?
    
    var body: some View {
        NavigationLink {
            LocationPicker(selectedLocationId: $selectedLocationId)
                .navigationTitle("Select Location")
        } label: {
            HStack {
                Text("Location")
                Spacer()
                if let locationId = selectedLocationId {
                    Text(locationManager.breadcrumbPath(for: locationId))
                        .foregroundColor(.secondary)
                } else {
                    Text("Select Location")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

#Preview {
    return Form {
        ItemLocationPicker(selectedLocationId: .constant(nil))
            .environmentObject(PreviewData.shared.locationManager)
    }
} 