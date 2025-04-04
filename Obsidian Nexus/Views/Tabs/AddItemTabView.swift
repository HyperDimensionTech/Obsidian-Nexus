import SwiftUI

struct AddItemTabView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    
    var body: some View {
        NavigationStack {
            AddItemView()
                .navigationTitle("Add Item")
                .navigationBarTitleDisplayMode(.large)
        }
    }
} 