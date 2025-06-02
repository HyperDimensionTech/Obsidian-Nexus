import SwiftUI

struct CollectionsGrid: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Collections")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)
                .padding(.top)
            
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(CollectionType.allCases, id: \.self) { type in
                    NavigationLink(value: type) {
                        EnhancedCollectionCard(type: type)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding()
        }
    }
}

/// Enhanced collection card with series information and quick actions
struct EnhancedCollectionCard: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    let type: CollectionType
    
    private var itemCount: Int {
        inventoryViewModel.itemCount(for: type)
    }
    
    private var seriesCount: Int {
        guard type.supportsSeriesGrouping else { return 0 }
        return inventoryViewModel.seriesForType(type).count
    }
    
    private var hasContent: Bool {
        itemCount > 0
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Main collection info
            VStack(spacing: 8) {
                Image(systemName: type.iconName)
                    .font(.system(size: 32))
                    .foregroundColor(type.color)
                
                Text(type.name)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 2) {
                    Text("\(itemCount) items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if type.supportsSeriesGrouping && seriesCount > 0 {
                        Text("\(seriesCount) series")
                            .font(.caption2)
                            .foregroundColor(type.color)
                    }
                }
            }
            
            // Quick actions for collections with content
            if hasContent && type.supportsSeriesGrouping && seriesCount > 0 {
                Button {
                    navigationCoordinator.navigate(to: .seriesView(type))
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.grid.2x2")
                            .font(.caption)
                        Text("View Series")
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(type.color.opacity(0.1))
                    .foregroundColor(type.color)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 140)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(hasContent ? type.color.opacity(0.3) : Color(.systemGray4), lineWidth: 1)
        )
    }
} 