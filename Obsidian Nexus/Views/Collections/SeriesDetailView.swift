import SwiftUI

struct SeriesDetailView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @State private var selectedItems: Set<UUID> = []
    @State private var isEditMode: EditMode = .inactive
    @State private var showingBulkEditSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteError = false
    @State private var deleteErrorMessage = ""
    
    let series: String
    let collectionType: CollectionType
    
    var seriesItems: [InventoryItem] {
        inventoryViewModel.itemsInSeries(series)
    }
    
    var seriesStats: (value: Price, count: Int) {
        inventoryViewModel.seriesStats(name: series)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Series stats section
            List {
                Section {
                    HStack {
                        Text("Total Value")
                        Spacer()
                        Text(seriesStats.value.convertedToDefaultCurrency().formatted())
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("\(collectionType.seriesItemTerminology.capitalized) Owned")
                        Spacer()
                        Text("\(seriesStats.count)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .frame(height: 120)
            .environment(\.editMode, .constant(.inactive))
            
            // Items list using ItemListComponent
            ItemListComponent(
                items: seriesItems,
                sectionTitle: collectionType.seriesItemTerminology.uppercased(),
                groupingStyle: .none,
                sortStyle: .volume,
                enableSelection: true,
                enableEditing: true,
                parentEditMode: $isEditMode,
                parentSelection: $selectedItems
            )
        }
        .navigationTitle(series)
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
                            selectedItems = Set(seriesItems.map { $0.id })
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
                EditItemView(items: inventoryViewModel.items.filter { selectedItems.contains($0.id) })
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

#Preview {
    NavigationView {
        SeriesDetailView(series: "Sample Series", collectionType: .manga)
            .environmentObject(InventoryViewModel(locationManager: PreviewData.shared.locationManager))
            .environmentObject(PreviewData.shared.locationManager)
    }
} 