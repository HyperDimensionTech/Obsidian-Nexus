import SwiftUI

struct ItemRow: View {
    @EnvironmentObject var locationManager: LocationManager
    let item: InventoryItem
    
    private var location: StorageLocation? {
        guard let id = item.locationId else { return nil }
        return locationManager.location(withId: id)
    }
    
    private var locationPath: String? {
        guard let id = item.locationId else { return nil }
        return locationManager.breadcrumbPath(for: id)
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(item.title)
                .font(.headline)
            
            HStack {
                Text(item.type.name)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let path = locationPath {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(path)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
} 