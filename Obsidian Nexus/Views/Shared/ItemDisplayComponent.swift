import SwiftUI

/**
 A reusable component for displaying inventory items consistently across the app.
 
 This component provides a standardized way to display item information while respecting
 user preferences from `UserPreferences.itemInfoDisplayOptions`.
 
 ## Usage
 
 ```swift
 // Basic usage with default settings
 ItemDisplayComponent(item: myItem)
 
 // Compact display for grid views
 ItemDisplayComponent(
     item: myItem,
     displayStyle: .compact
 )
 
 // Detailed display with all metadata
 ItemDisplayComponent(
     item: myItem,
     displayStyle: .detailed
 )
 
 // Custom display options (override user preferences)
 ItemDisplayComponent(
     item: myItem,
     customDisplayOptions: [.type, .price]
 )
 ```
 
 ## Display Styles
 
 - `.normal`: Standard display for list items (default)
 - `.compact`: Condensed display for grid views
 - `.detailed`: Expanded display with additional information
 
 ## Environment Requirements
 
 This component requires the following environment objects:
 - `@EnvironmentObject var locationManager: LocationManager`
 - `@EnvironmentObject var userPreferences: UserPreferences`
 */
struct ItemDisplayComponent: View {
    // MARK: - Properties
    
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var userPreferences: UserPreferences
    
    /// The item to display
    let item: InventoryItem
    
    /// Display style for the component
    var displayStyle: DisplayStyle = .normal
    
    /// Whether to show the full location path
    var showFullLocationPath: Bool = true
    
    /// Custom display options override user preferences when provided
    var customDisplayOptions: [UserPreferences.ItemInfoDisplayOption]?
    
    // MARK: - Computed Properties
    
    private var location: StorageLocation? {
        guard let id = item.locationId else { return nil }
        return locationManager.location(withId: id)
    }
    
    private var locationPath: String? {
        guard let id = item.locationId else { return nil }
        return showFullLocationPath ? locationManager.breadcrumbPath(for: id) : location?.name
    }
    
    private var displayOptions: [UserPreferences.ItemInfoDisplayOption] {
        customDisplayOptions ?? userPreferences.itemInfoDisplayOptions
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: displayStyle.spacing) {
            // Title
            Text(item.title)
                .font(displayStyle.titleFont)
                .lineLimit(displayStyle.titleLineLimit)
            
            // Secondary information (type, location, price)
            if !displayOptions.isEmpty {
                HStack(spacing: 4) {
                    // Build secondary info based on display preferences
                    ForEach(displayOptions.indices, id: \.self) { index in
                        let option = displayOptions[index]
                        
                        // Only add separator if there's a previous visible item
                        if index > 0 && hasVisibleInfo(forOption: displayOptions[index - 1]) {
                            if hasVisibleInfo(forOption: option) {
                                Text("•")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                        
                        // Display the requested info if available
                        if hasVisibleInfo(forOption: option) {
                            Text(infoText(for: option))
                                .font(displayStyle.metadataFont)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Additional content for detailed display
            if displayStyle == .detailed {
                detailedContent
            }
        }
    }
    
    // MARK: - Supporting Views
    
    /// Additional content shown only in detailed display mode
    @ViewBuilder
    private var detailedContent: some View {
        if let series = item.series, let volume = item.volume {
            HStack {
                Text("Series:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("\(series) Vol. \(volume)")
                    .font(.subheadline)
            }
        }
        
        if let creator = item.creator {
            HStack {
                Text("Creator:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(creator)
                    .font(.subheadline)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Check if the info for a specific option is available
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
    
    /// Get the text to display for a specific option
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

// MARK: - Supporting Types

extension ItemDisplayComponent {
    /**
     Display styles for the component
     
     Controls the visual appearance and information density of the component:
     - `.normal`: Standard display for list items
     - `.compact`: Condensed display for grid views
     - `.detailed`: Expanded display with additional information
     */
    enum DisplayStyle {
        /// Default style for list items
        case normal
        
        /// Compact style for grid views or constrained spaces
        case compact
        
        /// Detailed style with additional information
        case detailed
        
        /// Spacing between elements
        var spacing: CGFloat {
            switch self {
            case .normal: return 4
            case .compact: return 2
            case .detailed: return 8
            }
        }
        
        /// Font for the title
        var titleFont: Font {
            switch self {
            case .normal: return .headline
            case .compact: return .headline
            case .detailed: return .title3
            }
        }
        
        /// Font for metadata
        var metadataFont: Font {
            switch self {
            case .normal: return .subheadline
            case .compact: return .caption
            case .detailed: return .subheadline
            }
        }
        
        /// Line limit for title
        var titleLineLimit: Int {
            switch self {
            case .normal: return 1
            case .compact: return 1
            case .detailed: return 2
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let item = InventoryItem(
        title: "One Piece, Vol. 31",
        type: .manga,
        series: "One Piece",
        volume: 31,
        condition: .good,
        locationId: nil,
        price: Price(amount: 9.99, currency: .usd)
    )
    
    return VStack(spacing: 20) {
        ItemDisplayComponent(item: item, displayStyle: .normal)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .shadow(radius: 1)
        
        ItemDisplayComponent(item: item, displayStyle: .compact)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .shadow(radius: 1)
        
        ItemDisplayComponent(item: item, displayStyle: .detailed)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .shadow(radius: 1)
    }
    .padding()
    .background(Color(.systemGray6))
    .environmentObject(LocationManager())
    .environmentObject(UserPreferences())
} 