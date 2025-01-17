import SwiftUI

struct SearchResultRow: View {
    @EnvironmentObject var locationManager: LocationManager
    let item: InventoryItem
    
    private var locationPath: String? {
        guard let id = item.locationId else { return nil }
        return locationManager.breadcrumbPath(for: id)
    }
    
    private var typeIcon: String {
        switch item.type {
        case .books: return "book"
        case .manga: return "books.vertical"
        case .comics: return "magazine"
        case .games: return "gamecontroller"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .font(.headline)
            
            HStack {
                Label(item.type.name, systemImage: typeIcon)
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                
                if let path = locationPath {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(path)
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
            }
            
            Text(item.condition.rawValue.capitalized)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// Preview provider for testing
#Preview {
    SearchResultRow(item: InventoryItem(
        title: "Test Item",
        type: .books,
        series: "Test Series"
    ))
} 
