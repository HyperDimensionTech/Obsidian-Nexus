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
    @State private var navigateToAddItems = false

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
            }
            .padding()
            
            // Items and locations content
            if isLoading {
                VStack {
                    ProgressView()
                    Text("Loading items...")
                        .foregroundColor(.secondary)
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
                                    NavigationLink(destination: LocationItemsView(location: parent)
                                        .environmentObject(locationManager)
                                        .environmentObject(inventoryViewModel)
                                        .environmentObject(navigationCoordinator)
                                    ) {
                                        HStack {
                                            Image(systemName: "arrow.up.circle")
                                                .foregroundColor(.accentColor)
                                            Text(parent.name)
                                                .foregroundColor(.primary)
                                        }
                                        .onAppear {
                                            print("🔗 Parent link available: \(parent.name) (ID: \(parent.id))")
                                        }
                                    }
                                }
                            }
                            
                            // Show child locations if any
                            if !childLocations.isEmpty {
                                Section(header: Text("Child Locations")) {
                                    ForEach(childLocations) { childLocation in
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
                                            }
                                            .onAppear {
                                                print("🔗 Child link available: \(childLocation.name) (ID: \(childLocation.id), parent: \(childLocation.parentId?.uuidString ?? "none"))")
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
                            useCoordinator: false
                        )
                    } else if !isLoading {
                        // Empty state that maintains layout consistency
                        VStack(alignment: .leading) {
                            Text("Items in this location")
                                .font(.headline)
                                .padding(.horizontal)
                                .padding(.top)
                            
                            VStack(spacing: 12) {
                                Text("No items in this location")
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.top, 20)
                                
                                Button {
                                    navigateToAddItems = true
                                } label: {
                                    Label("Add Items", systemImage: "plus.circle")
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                }
                                .buttonStyle(.bordered)
                                .tint(.accentColor)
                                .padding(.bottom)
                            }
                            .frame(maxWidth: .infinity)
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }
                        Spacer(minLength: 0) // This pushes content to the top but doesn't center it
                    }
                }
            }
        }
        .navigationTitle("Location Items")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    navigateToAddItems = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            print("🔄 LocationItemsView.onAppear() for \(location.name)")
            // Reset state to ensure a fresh load
            isLoading = true
            items = []
            childLocations = []
            parentLocation = nil
            
            // Load data
            loadLocationHierarchy()
            loadItems()
        }
        .id(location.id) // Force view refresh when location changes
        .sheet(isPresented: $showingQRCode) {
            NavigationView {
                LocationQRCodeView(location: location)
                    .environmentObject(locationManager)
            }
        }
        .navigationDestination(isPresented: $navigateToAddItems) {
            AddItemsToLocationView(locationId: location.id)
                .environmentObject(inventoryViewModel)
                .environmentObject(locationManager)
                .environmentObject(navigationCoordinator)
        }
    }
    
    private func loadLocationHierarchy() {
        print("🔍 Loading location hierarchy for: \(location.name) (ID: \(location.id))")
        if let parentId = location.parentId {
            print("🔍 This location has parent ID: \(parentId)")
        } else {
            print("ℹ️ This is a root location with no parent")
        }
        
        Task { @MainActor in
            // Load parent location using the parentId from the location object
            let parentId = location.parentId
            let parent = parentId.flatMap { parentId -> StorageLocation? in
                let foundParent = self.locationManager.location(withId: parentId)
                print("🔍 Parent lookup: ID \(parentId) -> \(foundParent != nil ? "Found: \(foundParent!.name)" : "NOT FOUND")")
                return foundParent
            }
            
            if let parent = parent {
                print("✅ Found parent: \(parent.name) (ID: \(parent.id))")
            } else if location.parentId != nil {
                print("⚠️ Parent ID \(location.parentId!) exists but location not found in locationManager")
                // Try to fetch parent via async method if not found in memory
                await locationManager.loadLocation(withId: location.parentId!)
                // Check if parent loaded
                if let loadedParent = self.locationManager.location(withId: location.parentId!) {
                    self.parentLocation = loadedParent
                    print("✅ Loaded parent from database: \(loadedParent.name)")
                }
            } else {
                print("ℹ️ No parent ID for this location")
            }
            
            // Load child locations
            let children = locationManager.children(of: location.id)
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            print("✅ Found \(children.count) child locations")
            if !children.isEmpty {
                print("📋 Child locations: \(children.map { "\($0.name) (ID: \($0.id))" }.joined(separator: ", "))")
            }
            
            self.parentLocation = parent
            self.childLocations = children
            print("✅ UI updated with parent \(parent?.name ?? "none") and \(children.count) children")
        }
    }
    
    private func loadItems() {
        isLoading = true
        print("⏰ Loading items for location \(location.name) (ID: \(location.id))")
        
        Task { @MainActor in
            // Check for direct items in this location
            let directItems = self.inventoryViewModel.items.filter { $0.locationId == self.location.id }
            print("📦 Found \(directItems.count) direct items in this location")
            
            // Get all items including nested items
            let allItems = self.locationManager.getAllItemsInLocation(locationId: self.location.id, inventoryViewModel: self.inventoryViewModel)
            print("📦 Found \(allItems.count) total items (including nested) for location \(self.location.name)")
            
            if !allItems.isEmpty {
                print("📋 First few items: \(allItems.prefix(3).map { $0.title }.joined(separator: ", ")) ...")
            }
            
            self.items = allItems
            self.isLoading = false
            print("✅ UI updated with \(allItems.count) items, isLoading = false")
        }
    }
} 