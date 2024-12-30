import SwiftUI

struct CollectionsTabView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    
    var body: some View {
        NavigationView {
            CollectionsView()
        }
    }
} 