import SwiftUI

struct SeriesDetailView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var locationManager: LocationManager
    @State private var selectedItems: Set<UUID> = []
    @State private var isEditMode: EditMode = .inactive
    @State private var showingBulkEditSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteError = false
    @State private var deleteErrorMessage = ""
    
    let series: String
    
    var seriesItems: [InventoryItem] {
        inventoryViewModel.itemsInSeries(series)
    }
    
    var seriesStats: (value: Price, count: Int, total: Int?) {
        inventoryViewModel.seriesStats(name: series)
    }
    
    var body: some View {
        List(selection: $selectedItems) {
            Section {
                HStack {
                    Text("Total Value")
                    Spacer()
                    Text(seriesStats.value.convertedToDefaultCurrency().formatted())
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Volumes Owned")
                    Spacer()
                    Text("\(seriesStats.count)")
                        .foregroundColor(.secondary)
                }
                
                if let total = seriesStats.total {
                    HStack {
                        Text("Total Volumes")
                        Spacer()
                        Text("\(total)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Completion")
                        Spacer()
                        Text("\(Int((Double(seriesStats.count) / Double(total)) * 100))%")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section("Volumes") {
                ForEach(seriesItems) { item in
                    NavigationLink {
                        ItemDetailView(item: item)
                    } label: {
                        ItemRow(item: item)
                    }
                }
            }
        }
        .navigationTitle(series)
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
        SeriesDetailView(series: "Sample Series")
            .environmentObject(InventoryViewModel(locationManager: PreviewData.shared.locationManager))
            .environmentObject(PreviewData.shared.locationManager)
    }
} 