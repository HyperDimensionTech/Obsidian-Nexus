import SwiftUI

/// A reusable component for displaying item details in a consistent way
struct ItemDetailComponent: View {
    // MARK: - Properties
    
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var userPreferences: UserPreferences
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    
    /// The item to display details for
    let item: InventoryItem
    
    /// Which sections to show
    var sections: Set<Section> = [.basic, .metadata, .location, .series]
    
    /// Whether to enable navigation to related views
    var enableNavigation: Bool = true
    
    // MARK: - Computed Properties
    
    private var location: StorageLocation? {
        guard let id = item.locationId else { return nil }
        return locationManager.location(withId: id)
    }
    
    private var locationPath: String? {
        guard let id = item.locationId else { return nil }
        return locationManager.breadcrumbPath(for: id)
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            if sections.contains(.basic) {
                basicInfoSection
            }
            
            if sections.contains(.metadata) {
                metadataSection
            }
            
            if sections.contains(.location), location != nil {
                locationSection
            }
            
            if sections.contains(.series), item.series != nil {
                seriesSection
            }
        }
    }
    
    // MARK: - Supporting Views
    
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DetailRow(label: "Title", value: item.title)
            
            DetailRow(label: "Type", value: item.type.name)
            
            if let price = item.price {
                DetailRow(label: "Price", value: price.formatted())
            }
            
            DetailRow(label: "Condition", value: item.condition.rawValue)
            
            DetailRow(label: "Date Added", value: formatDate(item.dateAdded))
            
            if let purchaseDate = item.purchaseDate {
                DetailRow(label: "Purchase Date", value: formatDate(purchaseDate))
            }
        }
    }
    
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let creator = item.creator {
                DetailRow(label: "Creator", value: creator)
            }
            
            if let publisher = item.publisher {
                DetailRow(label: "Publisher", value: publisher)
            }
            
            if let originalDate = item.originalPublishDate {
                DetailRow(label: "Original Release", value: formatDate(originalDate))
            }
            
            if let isbn = item.isbn {
                DetailRow(label: "ISBN", value: isbn)
            }
            
            if let barcode = item.barcode {
                DetailRow(label: "Barcode", value: barcode)
            }
        }
    }
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let path = locationPath {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Path")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if enableNavigation, let id = item.locationId {
                        Button {
                            navigationCoordinator.navigateToLocation(locationId: id)
                        } label: {
                            Text(path)
                                .font(.body)
                                .multilineTextAlignment(.leading)
                        }
                    } else {
                        Text(path)
                            .font(.body)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
        }
    }
    
    private var seriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let series = item.series {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Series")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if enableNavigation {
                        Button {
                            navigationCoordinator.navigateToSeries(name: series)
                        } label: {
                            Text(series)
                                .font(.body)
                        }
                    } else {
                        Text(series)
                            .font(.body)
                    }
                }
            }
            
            if let volume = item.volume {
                DetailRow(label: "Volume", value: String(volume))
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Types

extension ItemDetailComponent {
    /// Available sections to display in the component
    enum Section: CaseIterable, Hashable {
        /// Basic information like title, type, condition
        case basic
        
        /// Metadata like author, publisher, release date
        case metadata
        
        /// Location information
        case location
        
        /// Series information
        case series
    }
}

// MARK: - Preview

#Preview {
    List {
        Section("Basic Information") {
            ItemDetailComponent(
                item: ItemDetailComponent.previewItem,
                sections: [.basic]
            )
        }
        
        Section("Metadata") {
            ItemDetailComponent(
                item: ItemDetailComponent.previewItem,
                sections: [.metadata]
            )
        }
        
        Section("Series Information") {
            ItemDetailComponent(
                item: ItemDetailComponent.previewItem,
                sections: [.series]
            )
        }
    }
    .environmentObject(LocationManager())
    .environmentObject(UserPreferences())
    .environmentObject(NavigationCoordinator())
}

// MARK: - Preview Helpers

extension ItemDetailComponent {
    static var previewItem: InventoryItem {
        InventoryItem(
            title: "One Piece, Vol. 31",
            type: .manga,
            series: "One Piece",
            volume: 31,
            condition: .good,
            locationId: nil,
            notes: "Great condition!",
            barcode: "9781421534466",
            author: "Eiichiro Oda",
            publisher: "Viz Media",
            isbn: "9781421534466",
            price: Price(amount: 9.99, currency: .usd),
            purchaseDate: Date()
        )
    }
} 