import SwiftUI

struct ItemRow: View {
    @EnvironmentObject var locationManager: LocationManager
    let item: InventoryItem
    
    private var location: StorageLocation? {
        guard let id = item.locationId else { return nil }
        return locationManager.location(withId: id)
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(item.title)
                .font(.headline)
            
            HStack {
                Text(item.type.name)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let location = location {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(location.name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
} 