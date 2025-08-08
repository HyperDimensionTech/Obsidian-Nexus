import SwiftUI

/**
 A generic view for displaying items grouped by series for any collection type.
 
 This replaces type-specific views like MangaSeriesView and will support
 future collection types automatically. Now includes List/Card view toggle.
 */
struct SeriesView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var userPreferences: UserPreferences
    @State private var selectedItems: Set<UUID> = []
    @State private var isEditMode: EditMode = .inactive
    @State private var showingBulkEditSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteError = false
    @State private var deleteErrorMessage = ""
    
    let collectionType: CollectionType
    
    var seriesData: [(String, [InventoryItem])] {
        inventoryViewModel.seriesForType(collectionType)
    }
    
    var allSeriesItems: [InventoryItem] {
        seriesData.flatMap { $0.1 }
    }
    
    var body: some View {
        // Use native iOS navigation structure for proper scrolling behavior
        Group {
            if userPreferences.viewMode == .list {
                listView
            } else {
                cardView
            }
        }
        .navigationTitle("\(collectionType.name) Series")
        .navigationBarTitleDisplayMode(.large)
        .environment(\.editMode, $isEditMode)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // View mode toggle on the right side
                if !seriesData.isEmpty {
                    ViewModeToggle(viewMode: $userPreferences.viewMode)
                }
                
                // 3-dot menu
                menuButton
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
                EditItemView(item: inventoryViewModel.items.first { selectedItems.contains($0.id) }!)
                    .environmentObject(inventoryViewModel)
                    .environmentObject(locationManager)
            }
        }
    }
    
    // MARK: - List View
    
    private var listView: some View {
        List(selection: $selectedItems) {
            ForEach(seriesData, id: \.0) { series, items in
                Section(header: Text(series)) {
                    ForEach(items) { item in
                        NavigationLink {
                            ItemDetailView(item: item)
                        } label: {
                            ItemRow(item: item)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Card View
    
    private var cardView: some View {
        CardGridView(
            items: allSeriesItems,
            showSeriesGrouping: true
        )
        .environmentObject(inventoryViewModel)
        .environmentObject(locationManager)
    }
    
    @ViewBuilder
    private var menuButton: some View {
        if isEditMode == .inactive {
            Menu {
                Button("Select Items") {
                    isEditMode = .active
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        } else {
            Menu {
                editMenuButton
                selectAllButton
                deleteButton
                doneButton
            } label: {
                Text("Edit")
            }
        }
    }
    
    private var editMenuButton: some View {
        Button("Edit Selected (\(selectedItems.count))") {
            showingBulkEditSheet = true
        }
        .disabled(selectedItems.isEmpty)
    }
    
    private var selectAllButton: some View {
        Button("Select All") {
            selectedItems = Set(allSeriesItems.map { $0.id })
        }
    }
    
    private var deleteButton: some View {
        Button("Delete Selected", role: .destructive) {
            showingDeleteConfirmation = true
        }
        .disabled(selectedItems.isEmpty)
    }
    
    private var doneButton: some View {
        Button("Done") {
            isEditMode = .inactive
            selectedItems.removeAll()
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
        SeriesView(collectionType: .manga)
            .environmentObject(PreviewData.shared.inventoryViewModel)
            .environmentObject(PreviewData.shared.locationManager)
    }
} 