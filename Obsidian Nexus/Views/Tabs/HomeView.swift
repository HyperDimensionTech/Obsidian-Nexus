import SwiftUI

struct HomeView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    
    var body: some View {
        NavigationView {
            DashboardView()
        }
    }
} 