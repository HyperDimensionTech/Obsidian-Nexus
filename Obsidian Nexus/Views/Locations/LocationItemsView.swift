import SwiftUI

struct LocationItemsView: View {
    let location: StorageLocation
    
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    @State private var items: [InventoryItem] = []
    @State private var isLoading = true
    @State private var showingQRCode = false
    @State private var childLocations: [StorageLocation] = []
    @State private var parentLocation: StorageLocation?
    
    var body: some View {
        VStack {
            // Location header
            HStack {
                Image(systemName: location.type.icon)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                Text(location.name)
                    .font(.title2)
                    .bold()
                
                Spacer()
                
                Button {
                    DispatchQueue.main.async {
                        showingQRCode = true
                    }
                } label: {
                    HStack {
                        Image(systemName: "qrcode")
                        Text("QR Code")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            .padding()
            
            // Items and locations content
            if isLoading {
                Spacer()
                ProgressView()
                    .padding()
                Spacer()
            } else if items.isEmpty && childLocations.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "tray")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("No items in this location")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Button {
                        DispatchQueue.main.async {
                            // Navigate to add items
                            navigationCoordinator.navigate(to: .addItems(location.id))
                        }
                    } label: {
                        HStack {
                            Image(systemName: "plus")
                            Text("Add Items")
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .padding()
                Spacer()
            } else {
                VStack(spacing: 0) {
                    // Parent/Child Locations List
                    if parentLocation != nil || !childLocations.isEmpty {
                        List {
                            // Show parent location if any
                            if let parent = parentLocation {
                                Section(header: Text("Parent Location")) {
                                    Button {
                                        navigationCoordinator.navigate(to: .locationDetail(parent))
                                    } label: {
                                        HStack {
                                            Image(systemName: "arrow.up.circle")
                                                .foregroundColor(.accentColor)
                                            Text(parent.name)
                                                .foregroundColor(.primary)
                                        }
                                    }
                                }
                            }
                            
                            // Show child locations if any
                            if !childLocations.isEmpty {
                                Section(header: Text("Child Locations")) {
                                    ForEach(childLocations) { childLocation in
                                        Button {
                                            navigationCoordinator.navigate(to: .locationDetail(childLocation))
                                        } label: {
                                            HStack {
                                                Image(systemName: childLocation.type.icon)
                                                    .foregroundColor(.accentColor)
                                                Text(childLocation.name)
                                                    .foregroundColor(.primary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .listStyle(InsetGroupedListStyle())
                        .frame(height: (parentLocation != nil && !childLocations.isEmpty) ? 200 : 120)
                    }
                    
                    // Items list using ItemListComponent
                    if !items.isEmpty {
                        ItemListComponent(
                            items: items,
                            sectionTitle: "Items in this location",
                            groupingStyle: .none,
                            sortStyle: .title,
                            useCoordinator: true
                        )
                    }
                }
            }
        }
        .navigationTitle("Location Items")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    DispatchQueue.main.async {
                        navigationCoordinator.navigate(to: .addItems(location.id))
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            loadItems()
            loadLocationRelationships()
        }
        .sheet(isPresented: $showingQRCode) {
            NavigationView {
                LocationQRCodeView(location: location)
                    .environmentObject(locationManager)
            }
        }
    }
    
    private func loadLocationRelationships() {
        DispatchQueue.global(qos: .userInitiated).async {
            // Load parent location
            let parent = location.parentId.flatMap { locationManager.location(withId: $0) }
            
            // Load child locations
            let children = locationManager.children(of: location.id)
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            
            DispatchQueue.main.async {
                parentLocation = parent
                childLocations = children
            }
        }
    }
    
    private func loadItems() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let allItems = locationManager.getAllItemsInLocation(locationId: location.id, inventoryViewModel: inventoryViewModel)
            DispatchQueue.main.async {
                items = allItems
                isLoading = false
            }
        }
    }
} 