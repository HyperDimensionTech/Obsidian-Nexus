import SwiftUI

struct SearchResultRow: View {
    let item: InventoryItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Add thumbnail image if available
            if let url = item.thumbnailURL {
                ThumbnailImage(url: url, type: item.type)
                    .frame(width: 50, height: 50)
            } else {
                Image(systemName: item.type.iconName)
                    .foregroundColor(item.type.color)
                    .frame(width: 50, height: 50)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)
                
                if let series = item.series {
                    Text(series)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack {
                    Image(systemName: item.type.iconName)
                        .foregroundColor(item.type.color)
                    Text(item.type.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle()) // Ensure the entire row is tappable
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