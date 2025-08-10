import SwiftUI

struct MangaSeriesView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var locationManager: LocationManager
    @State private var selectedItems: Set<UUID> = []
    @State private var isEditMode: EditMode = .inactive
    @State private var showingBulkEditSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteError = false
    @State private var deleteErrorMessage = ""
    
    var mangaSeries: [(String, [InventoryItem])] {
        inventoryViewModel.mangaSeries()
    }
    
    var body: some View {
        List(selection: $selectedItems) {
            ForEach(mangaSeries, id: \.0) { series, items in
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
        .navigationTitle("Manga Series")
        .environment(\.editMode, $isEditMode)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                toolbarButton
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
    
    @ViewBuilder
    private var toolbarButton: some View {
        if isEditMode == .inactive {
            Button("Select") {
                isEditMode = .active
            }
        } else {
            editModeMenu
        }
    }
    
    private var editModeMenu: some View {
        Menu {
            editSelectedButton
            selectAllButton
            deleteButton
            doneButton
        } label: {
            Text("Edit")
        }
    }
    
    private var editSelectedButton: some View {
        Button("Edit Selected (\(selectedItems.count))") {
            showingBulkEditSheet = true
        }
        .disabled(selectedItems.isEmpty)
    }
    
    private var selectAllButton: some View {
        Button("Select All") {
            selectedItems = Set(
                mangaSeries.flatMap { $0.1 }.map { $0.id }
            )
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
        MangaSeriesView()
            .environmentObject(PreviewData.shared.inventoryViewModel)
            .environmentObject(PreviewData.shared.locationManager)
    }
} 