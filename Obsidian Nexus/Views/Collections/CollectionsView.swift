import SwiftUI

struct CollectionsView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                ForEach(CollectionType.literatureTypes, id: \.self) { type in
                    NavigationLink(destination: CollectionDetailView(type: type)) {
                        CollectionCard(type: type)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Collections")
    }
}

#Preview {
    CollectionsView()
        .environmentObject(InventoryViewModel(locationManager: LocationManager()))
        .environmentObject(NavigationCoordinator())
} 