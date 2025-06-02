import SwiftUI

/**
 A card-based grid view for displaying inventory items with large thumbnails.
 
 This component provides an attractive alternative to list views, particularly
 useful for series browsing where visual identification is important.
 */
struct CardGridView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @StateObject private var thumbnailService = ThumbnailService()
    
    let items: [InventoryItem]
    let showSeriesGrouping: Bool
    var onItemTap: ((InventoryItem) -> Void)?
    
    // Grid configuration
    private let gridColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    private let cardSpacing: CGFloat = 16
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: cardSpacing) {
                if showSeriesGrouping {
                    // Group items by series and show series cards
                    ForEach(groupedBySeries, id: \.key) { seriesName, seriesItems in
                        SeriesCardView(
                            seriesName: seriesName,
                            items: seriesItems,
                            collectionType: seriesItems.first?.type ?? .books
                        )
                    }
                } else {
                    // Show individual item cards
                    ForEach(items) { item in
                        ItemCardView(item: item)
                            .onTapGesture {
                                if let onItemTap = onItemTap {
                                    onItemTap(item)
                                } else {
                                    navigationCoordinator.navigateToItemDetail(item: item)
                                }
                            }
                    }
                }
            }
            .padding(.horizontal, cardSpacing)
            .padding(.vertical, 8)
        }
    }
    
    // Group items by series for series cards
    private var groupedBySeries: [(key: String, value: [InventoryItem])] {
        let grouped = Dictionary(grouping: items) { item in
            item.series ?? "No Series"
        }
        return grouped.sorted { $0.key < $1.key }
    }
}

// MARK: - Item Card View

/**
 Individual item card with thumbnail and metadata
 */
struct ItemCardView: View {
    @EnvironmentObject var userPreferences: UserPreferences
    let item: InventoryItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Thumbnail area
            ThumbnailCardView(
                url: item.thumbnailURL,
                type: item.type,
                hasCustomImage: item.customImageData != nil,
                customImageData: item.customImageData
            )
            
            // Item information
            VStack(alignment: .leading, spacing: 6) {
                // Title
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                // Series and Volume
                if let series = item.series {
                    HStack {
                        Image(systemName: "book.closed")
                            .foregroundColor(item.type.color)
                            .font(.caption)
                        if let volume = item.volume {
                            Text("\(series) Vol. \(volume)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text(series)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .lineLimit(1)
                }
                
                // Metadata row
                HStack(spacing: 8) {
                    // Type badge
                    HStack(spacing: 4) {
                        Image(systemName: item.type.iconName)
                            .font(.caption2)
                        Text(item.type.name)
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(item.type.color.opacity(0.1))
                    .foregroundColor(item.type.color)
                    .cornerRadius(6)
                    
                    Spacer()
                    
                    // Price
                    if let price = item.price {
                        Text(price.formatted())
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }
}

// MARK: - Series Card View

/**
 Series card showing first item thumbnail with series information
 */
struct SeriesCardView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    let seriesName: String
    let items: [InventoryItem]
    let collectionType: CollectionType
    
    private var firstItem: InventoryItem? {
        items.sorted { item1, item2 in
            if let vol1 = item1.volume, let vol2 = item2.volume {
                return vol1 < vol2
            }
            return item1.title < item2.title
        }.first
    }
    
    private var seriesValue: Price {
        let totalValue = items.compactMap { $0.price?.amount }.reduce(0, +)
        return Price(amount: totalValue)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Series thumbnail (first item's image)
            ThumbnailCardView(
                url: firstItem?.thumbnailURL,
                type: collectionType,
                hasCustomImage: firstItem?.customImageData != nil,
                customImageData: firstItem?.customImageData
            )
            .overlay(
                // Series indicator overlay
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 2) {
                            Image(systemName: "square.stack.3d.up")
                                .font(.caption)
                            Text("\(items.count)")
                                .font(.caption2)
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                        .foregroundColor(.primary)
                    }
                    .padding(8)
                }
            )
            
            // Series information
            VStack(alignment: .leading, spacing: 6) {
                // Series name
                Text(seriesName)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                // Series stats
                HStack {
                    Image(systemName: collectionType.iconName)
                        .foregroundColor(collectionType.color)
                        .font(.caption)
                    Text("\(items.count) \(collectionType.seriesItemTerminology)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Value and completion
                HStack(spacing: 8) {
                    // Type badge
                    HStack(spacing: 4) {
                        Image(systemName: collectionType.iconName)
                            .font(.caption2)
                        Text(collectionType.name)
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(collectionType.color.opacity(0.1))
                    .foregroundColor(collectionType.color)
                    .cornerRadius(6)
                    
                    Spacer()
                    
                    // Series value
                    if seriesValue.amount > 0 {
                        Text(seriesValue.formatted())
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(collectionType.color.opacity(0.3), lineWidth: 1.5)
        )
        .onTapGesture {
            navigationCoordinator.navigate(to: .seriesDetail(seriesName, collectionType))
        }
    }
}

// MARK: - Thumbnail Card View

/**
 Reusable thumbnail view for cards with proper aspect ratio and styling
 */
struct ThumbnailCardView: View {
    let url: URL?
    let type: CollectionType
    let hasCustomImage: Bool
    let customImageData: Data?
    
    var body: some View {
        ZStack {
            if hasCustomImage, let imageData = customImageData,
               let uiImage = UIImage(data: imageData) {
                // Custom image
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 180)
                    .clipped()
            } else if let url = url {
                // Remote image
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        thumbnailPlaceholder
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: type.color))
                            )
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 180)
                            .clipped()
                    case .failure:
                        thumbnailPlaceholder
                    @unknown default:
                        thumbnailPlaceholder
                    }
                }
            } else {
                // No image placeholder
                thumbnailPlaceholder
            }
        }
        .frame(height: 180)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var thumbnailPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: type.iconName)
                .font(.system(size: 32))
                .foregroundColor(type.color)
            Text(type.name)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGray6))
    }
}

// MARK: - Preview

#Preview {
    let sampleItems = [
        InventoryItem(
            title: "One Piece, Vol. 1",
            type: .manga,
            series: "One Piece",
            volume: 1,
            condition: .good,
            locationId: nil,
            price: Price(amount: 9.99)
        ),
        InventoryItem(
            title: "Naruto, Vol. 1",
            type: .manga,
            series: "Naruto",
            volume: 1,
            condition: .good,
            locationId: nil,
            price: Price(amount: 8.99)
        )
    ]
    
    return NavigationView {
        CardGridView(items: sampleItems, showSeriesGrouping: false)
            .environmentObject(InventoryViewModel(locationManager: LocationManager()))
            .environmentObject(LocationManager())
            .environmentObject(NavigationCoordinator())
            .environmentObject(UserPreferences())
    }
} 