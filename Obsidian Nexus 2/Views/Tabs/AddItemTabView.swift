import SwiftUI

struct AddItemTabView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    
    var body: some View {
        NavigationView {
            AddItemView()
        }
    }
} 