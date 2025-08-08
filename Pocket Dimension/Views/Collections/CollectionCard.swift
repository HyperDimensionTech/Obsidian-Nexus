import SwiftUI

struct CollectionCard: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    let type: CollectionType
    
    var body: some View {
        VStack {
            Image(systemName: type.iconName)
                .font(.largeTitle)
                .foregroundColor(type.color)
            
            Text(type.name)
                .font(.headline)
                .lineLimit(1)
            
            Text("\(inventoryViewModel.itemCount(for: type)) items")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
} 