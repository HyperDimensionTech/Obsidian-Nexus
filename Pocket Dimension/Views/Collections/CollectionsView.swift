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
        .environmentObject(InventoryViewModel(storage: ServiceContainer.shared.storage,
                                              locationManager: LocationManager(storage: StorageManager.shared),
                                              validator: ServiceContainer.shared.validator,
                                              search: ServiceContainer.shared.search,
                                              stats: ServiceContainer.shared.stats,
                                              collectionService: CollectionManagementService()))
        .environmentObject(NavigationCoordinator())
} 