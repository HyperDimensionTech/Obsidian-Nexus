import SwiftUI

struct StatsOverviewCard: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Collection Overview")
                .font(.headline)
            
            HStack {
                StatBox(title: "Total Items", value: "\(inventoryViewModel.totalItems)")
                StatBox(title: "Collections", value: "\(CollectionType.allCases.count)")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

struct StatBox: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2)
                .bold()
        }
        .frame(maxWidth: .infinity)
    }
} 