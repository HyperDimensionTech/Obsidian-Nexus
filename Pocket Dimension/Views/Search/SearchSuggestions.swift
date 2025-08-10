import SwiftUI

struct SearchSuggestions: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Searches")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    // Only show literature types
                    ForEach(CollectionType.literatureTypes, id: \.self) { type in
                        Button(action: {
                            // TODO: Implement search suggestion action
                        }) {
                            HStack {
                                Image(systemName: type.iconName)
                                    .foregroundColor(type.color)
                                Text("Browse \(type.name)")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
        }
        .padding(.vertical)
    }
} 