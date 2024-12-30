import SwiftUI

struct SearchTabView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    
    var body: some View {
        NavigationView {
            SearchView()
        }
    }
} 