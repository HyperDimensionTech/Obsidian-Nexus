import SwiftUI

struct BooksByAuthorView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var locationManager: LocationManager
    @State private var selectedItems: Set<UUID> = []
    @State private var isEditMode: EditMode = .inactive
    @State private var showingBulkEditSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteError = false
    @State private var deleteErrorMessage = ""
    
    let author: String
    
    var authorItems: [InventoryItem] {
        inventoryViewModel.itemsByAuthor(author)
    }
    
    var authorStats: (value: Price, count: Int) {
        inventoryViewModel.authorStats(name: author)
    }
    
    var body: some View {
        List(selection: $selectedItems) {
            Section {
                HStack {
                    Text("Total Value")
                    Spacer()
                    Text(authorStats.value.convertedToDefaultCurrency().formatted())
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Number of Books")
                    Spacer()
                    Text("\(authorStats.count)")
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Books") {
                ForEach(authorItems) { item in
                    NavigationLink(destination: ItemDetailView(item: item)) {
                        VStack(alignment: .leading) {
                            Text(item.title)
                                .font(.headline)
                            if let price = item.price {
                                Text(price.convertedToDefaultCurrency().formatted())
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(author)
        .environment(\.editMode, $isEditMode)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditMode == .inactive {
                    Button("Select") {
                        isEditMode = .active
                    }
                } else {
                    Menu {
                        Button("Edit Selected (\(selectedItems.count))") {
                            showingBulkEditSheet = true
                        }
                        .disabled(selectedItems.isEmpty)
                        
                        Button("Select All") {
                            selectedItems = Set(
                                authorItems.map { $0.id }
                            )
                        }
                        
                        Button("Delete Selected", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                        .disabled(selectedItems.isEmpty)
                        
                        Button("Done") {
                            isEditMode = .inactive
                            selectedItems.removeAll()
                        }
                    } label: {
                        Text("Edit")
                    }
                }
            }
        }
        .alert("Confirm Deletion", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteSelectedItems()
            }
        } message: {
            Text("Are you sure you want to delete \(selectedItems.count) items? This action cannot be undone.")
        }
        .alert("Delete Error", isPresented: $showingDeleteError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(deleteErrorMessage)
        }
        .sheet(isPresented: $showingBulkEditSheet) {
            NavigationStack {
                EditItemView(items: authorItems)
                    .environmentObject(inventoryViewModel)
                    .environmentObject(locationManager)
            }
        }
    }
    
    private func deleteSelectedItems() {
        do {
            try inventoryViewModel.bulkDeleteItems(with: selectedItems)
            isEditMode = .inactive
            selectedItems.removeAll()
        } catch {
            deleteErrorMessage = error.localizedDescription
            showingDeleteError = true
        }
    }
} 