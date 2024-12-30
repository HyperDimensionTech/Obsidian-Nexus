import SwiftUI

struct ItemDetailView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var locationManager: LocationManager
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    
    let item: InventoryItem
    
    private var location: StorageLocation? {
        guard let id = item.locationId else { return nil }
        return locationManager.location(withId: id)
    }
    
    var body: some View {
        List {
            Section("Basic Details") {
                DetailRow(label: "Name", value: item.title)
                if let creator = item.creator {
                    DetailRow(label: item.type.isLiterature ? "Author" : "Manufacturer", 
                             value: creator)
                }
                DetailRow(label: "Type", value: item.type.name)
                DetailRow(label: "Condition", value: item.condition.rawValue)
                
                if let date = item.originalPublishDate {
                    DetailRow(label: "Original Publish Date", 
                            value: date.formatted(date: .long, time: .omitted))
                }
            }
            
            Section("Purchase Information") {
                if let price = item.price {
                    DetailRow(label: "Price", 
                            value: price.formatted(.currency(code: "USD")))
                }
                if let date = item.purchaseDate {
                    DetailRow(label: "Purchase Date", 
                            value: date.formatted(date: .long, time: .omitted))
                }
                if let location = location {
                    DetailRow(label: "Location", value: location.name)
                }
            }
            
            if let synopsis = item.synopsis {
                Section("Details") {
                    Text(synopsis)
                        .font(.body)
                }
            }
            
            // Keep literature-specific section for additional details
            if item.type.isLiterature {
                Section("Additional Details") {
                    if let publisher = item.publisher {
                        DetailRow(label: "Publisher", value: publisher)
                    }
                    if let isbn = item.isbn {
                        DetailRow(label: "ISBN", value: isbn)
                    }
                }
            }
        }
        .navigationTitle(item.title)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Edit") {
                        showingEditSheet = true
                    }
                    Button("Delete", role: .destructive) {
                        showingDeleteAlert = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditItemView(item: item)
                .environmentObject(inventoryViewModel)
                .environmentObject(locationManager)
        }
        .alert("Delete Item", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                inventoryViewModel.deleteItem(item)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this item? This action cannot be undone.")
        }
    }
}

#Preview {
    let locationManager = LocationManager()
    let inventoryViewModel = InventoryViewModel(locationManager: locationManager)
    
    let sampleItem = InventoryItem(
        title: "Sample Item",
        type: .books
    )
    
    return NavigationView {
        ItemDetailView(item: sampleItem)
            .environmentObject(locationManager)
            .environmentObject(inventoryViewModel)
    }
} 