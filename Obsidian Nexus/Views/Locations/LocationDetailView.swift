import SwiftUI

struct LocationDetailView: View {
    let location: StorageLocation
    
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    @State private var showingQRCode = false
    @State private var items: [InventoryItem] = []
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Location header
                HStack {
                    Image(systemName: location.type.icon)
                        .font(.title)
                        .foregroundColor(.accentColor)
                    
                    Text(location.name)
                        .font(.title)
                        .bold()
                    
                    Spacer()
                    
                    Button {
                        showingQRCode = true
                    } label: {
                        Image(systemName: "qrcode")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                    }
                }
                .padding(.horizontal)
                
                // Path
                Text(locationManager.breadcrumbPath(for: location.id))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                Divider()
                
                // Items in this location
                VStack(alignment: .leading, spacing: 12) {
                    Text("Items")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if items.isEmpty {
                        Text("No items in this location")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(items) { item in
                                ItemRow(item: item)
                                    .padding(.horizontal)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        navigationCoordinator.navigate(to: .itemDetail(item))
                                    }
                                    .padding(.vertical, 4)
                                
                                if items.last?.id != item.id {
                                    Divider()
                                        .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
                
                // Child locations
                VStack(alignment: .leading, spacing: 12) {
                    Text("Child Locations")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    let children = locationManager.children(of: location.id)
                    
                    if children.isEmpty {
                        Text("No child locations")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(children) { childLocation in
                                NavigationLink(destination: LocationItemsView(location: childLocation)
                                    .environmentObject(locationManager)
                                    .environmentObject(inventoryViewModel)
                                    .environmentObject(navigationCoordinator)
                                ) {
                                    HStack {
                                        Image(systemName: childLocation.type.icon)
                                            .foregroundColor(.accentColor)
                                        Text(childLocation.name)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.gray)
                                            .font(.caption)
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                }
                                
                                if children.last?.id != childLocation.id {
                                    Divider()
                                        .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Location Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            print("🔄 LocationDetailView.onAppear() for \(location.name)")
            loadItems()
        }
        .id(location.id) // Force view refresh when location changes
        .sheet(isPresented: $showingQRCode) {
            NavigationView {
                LocationQRCodeView(location: location)
            }
        }
    }
    
    private func loadItems() {
        isLoading = true
        print("⏰ Loading items for location \(location.name) (ID: \(location.id))")
        // Get all items in this location, including nested items
        DispatchQueue.global(qos: .userInitiated).async {
            let allItems = locationManager.getAllItemsInLocation(locationId: location.id, inventoryViewModel: inventoryViewModel)
            print("✅ Found \(allItems.count) items for location \(location.name)")
            DispatchQueue.main.async {
                items = allItems
                isLoading = false
                print("✅ UI updated with \(allItems.count) items, isLoading = false")
            }
        }
    }
} 