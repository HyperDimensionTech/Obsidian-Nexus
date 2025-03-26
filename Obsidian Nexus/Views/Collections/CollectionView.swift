import SwiftUI

struct CollectionView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var locationManager: LocationManager
    @State private var selectedItems: Set<UUID> = []
    @State private var isEditMode: EditMode = .inactive
    @State private var showingBulkEditSheet = false
    @State private var bookSortStyle: BookSortStyle = .author
    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteError = false
    @State private var deleteErrorMessage = ""
    
    let type: CollectionType
    
    enum BookSortStyle {
        case author
        case alphabetical
    }
    
    var items: [InventoryItem] {
        inventoryViewModel.items(for: type)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if type == .books {
                Picker("Sort Style", selection: $bookSortStyle) {
                    Text("By Author").tag(BookSortStyle.author)
                    Text("Alphabetical").tag(BookSortStyle.alphabetical)
                }
                .pickerStyle(.segmented)
                .padding()
            }
            
            List(selection: $selectedItems) {
                if type == .manga {
                    // Group manga by series
                    ForEach(inventoryViewModel.mangaSeries(), id: \.0) { series, seriesItems in
                        NavigationLink {
                            SeriesDetailView(series: series)
                        } label: {
                            SeriesGroupRow(series: series, itemCount: seriesItems.count)
                        }
                    }
                } else if type == .books {
                    if bookSortStyle == .author {
                        // Books by author grouping
                        ForEach(inventoryViewModel.booksByAuthor(), id: \.0) { author, authorItems in
                            NavigationLink {
                                BooksByAuthorView(author: author)
                            } label: {
                                AuthorGroupRow(author: author, itemCount: authorItems.count)
                            }
                        }
                    } else {
                        // Alphabetical listing
                        ForEach(items.sorted { $0.title < $1.title }) { item in
                            NavigationLink {
                                ItemDetailView(item: item)
                            } label: {
                                ItemRow(item: item)
                            }
                        }
                    }
                } else {
                    // Show individual items for other collection types
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
        .navigationTitle(type.name)
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
                            selectedItems = Set(items.map { $0.id })
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
            selectedItems.removeAll()
            isEditMode = .inactive
        } catch {
            deleteErrorMessage = error.localizedDescription
            showingDeleteError = true
        }
    }
}

// MARK: - Supporting Views

/// Displays a series group with consistent styling
struct SeriesGroupRow: View {
    let series: String
    let itemCount: Int
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(series)
                .font(.headline)
            Text("\(itemCount) volumes")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

/// Displays an author group with consistent styling
struct AuthorGroupRow: View {
    let author: String
    let itemCount: Int
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(author)
                .font(.headline)
            Text("\(itemCount) books")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        CollectionView(type: .manga)
            .environmentObject(InventoryViewModel(locationManager: LocationManager()))
            .environmentObject(LocationManager())
    }
} 