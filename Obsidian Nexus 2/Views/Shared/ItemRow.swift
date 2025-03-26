import SwiftUI

struct ItemRow: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var userPreferences: UserPreferences
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
            
            HStack(spacing: 4) {
                // Build secondary info based on display preferences
                ForEach(userPreferences.itemInfoDisplayOptions.indices, id: \.self) { index in
                    let option = userPreferences.itemInfoDisplayOptions[index]
                    
                    // Only add separator if there's a previous visible item
                    if index > 0 && hasVisibleInfo(forOption: userPreferences.itemInfoDisplayOptions[index - 1]) {
                        if hasVisibleInfo(forOption: option) {
                            Text("•")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    
                    // Display the requested info if available
                    if hasVisibleInfo(forOption: option) {
                        Text(infoText(for: option))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // Check if the info for a specific option is available
    private func hasVisibleInfo(forOption option: UserPreferences.ItemInfoDisplayOption) -> Bool {
        switch option {
        case .type:
            return true // Type is always available
        case .location:
            return locationPath != nil
        case .price:
            return item.price != nil
        case .none:
            return false
        }
    }
    
    // Get the text to display for a specific option
    private func infoText(for option: UserPreferences.ItemInfoDisplayOption) -> String {
        switch option {
        case .type:
            return item.type.name
        case .location:
            return locationPath ?? ""
        case .price:
            if let price = item.price {
                return price.formatted()
            }
            return ""
        case .none:
            return ""
        }
    }
} 