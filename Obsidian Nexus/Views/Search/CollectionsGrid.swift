import SwiftUI

struct CollectionsGrid: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    
    // Only show ready collection types for now
    private let readyCollectionTypes: [CollectionType] = CollectionType.readyTypes
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Collections")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(readyCollectionTypes, id: \.self) { type in
                    NavigationLink(value: type) {
                        SimplifiedCollectionCard(type: type)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

/// Simplified collection card with clean design and uniform styling
struct SimplifiedCollectionCard: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    let type: CollectionType
    
    private var itemCount: Int {
        inventoryViewModel.itemCount(for: type)
    }
    
    private var hasContent: Bool {
        itemCount > 0
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Icon
            Image(systemName: type.iconName)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(type.color)
            
            // Collection name
            Text(type.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
} 