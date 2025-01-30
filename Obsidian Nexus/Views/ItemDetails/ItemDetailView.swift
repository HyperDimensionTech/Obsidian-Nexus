import SwiftUI

struct ItemDetailView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var locationManager: LocationManager
    @StateObject private var thumbnailService = ThumbnailService()
    
    @State private var thumbnailURL: URL?
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    let item: InventoryItem
    
    private var location: StorageLocation? {
        guard let id = item.locationId else { return nil }
        return locationManager.location(withId: id)
    }
    
    var body: some View {
        List {
            if item.type.isLiterature {
                Section {
                    HStack {
                        Spacer()
                        if let url = thumbnailURL {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(height: 200)
                        } else {
                            Image(systemName: "book")
                                .font(.system(size: 100))
                                .foregroundColor(.gray)
                                .frame(height: 200)
                        }
                        Spacer()
                    }
                }
            }
            
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
                if let purchaseDate = item.purchaseDate {
                    DetailRow(label: "Purchase Date", 
                            value: purchaseDate.formatted(date: .long, time: .omitted))
                }
                if let locationId = item.locationId {
                    DetailRow(
                        label: "Location", 
                        value: locationManager.breadcrumbPath(for: locationId)
                    )
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
                deleteItem()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this item? This action cannot be undone.")
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        if let existingURL = item.thumbnailURL {
            print("Using existing thumbnail URL: \(existingURL)")  // Debug
            thumbnailURL = existingURL
        }
    }
    
    private func deleteItem() {
        do {
            try inventoryViewModel.deleteItem(item)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
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