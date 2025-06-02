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
    @State private var viewMode: ViewMode = .list
    
    let type: CollectionType
    
    enum BookSortStyle {
        case author
        case series
        case alphabetical
    }
    
    var items: [InventoryItem] {
        inventoryViewModel.items(for: type)
    }
    
    var body: some View {
        // Use native iOS navigation structure for proper scrolling behavior
        Group {
            if type == .books {
                // Books get special treatment with sort style picker at the top
                VStack(spacing: 0) {
                    // Books sort style picker
                    Picker("Sort Style", selection: $bookSortStyle) {
                        Text("By Author").tag(BookSortStyle.author)
                        Text("By Series").tag(BookSortStyle.series)
                        Text("Alphabetical").tag(BookSortStyle.alphabetical)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    .background(Color(.systemBackground))
                    
                    // Content
                    contentView
                }
            } else {
                // Other collection types use direct content
                contentView
            }
        }
        .navigationTitle(type.name)
        .navigationBarTitleDisplayMode(.large)
        .environment(\.editMode, $isEditMode)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // View mode toggle on the right side
                if shouldShowViewModeToggle {
                    ViewModeToggle(viewMode: $viewMode)
                }
                
                // 3-dot menu
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
    
    // MARK: - Helper Properties
    
    private var shouldShowViewModeToggle: Bool {
        // Show toggle for series grouping or individual items (but not author grouping)
        if type == .books && bookSortStyle == .author {
            return false
        }
        return !items.isEmpty
    }
    
    // MARK: - Content View
    
    @ViewBuilder
    private var contentView: some View {
        if type == .books && bookSortStyle == .author {
            // Books by author - always list view
            authorListView
        } else if type == .books && bookSortStyle == .series {
            // Books by series - can toggle view mode
            if viewMode == .list {
                seriesListView(for: .books)
            } else {
                seriesCardView(for: .books)
            }
        } else if type.supportsSeriesGrouping {
            // Other collection types with series support
            if viewMode == .list {
                seriesListView(for: type)
            } else {
                seriesCardView(for: type)
            }
        } else {
            // Individual items view
            if viewMode == .list {
                itemsListView
            } else {
                itemsCardView
            }
        }
    }
    
    // MARK: - View Components
    
    private var authorListView: some View {
        List(selection: $selectedItems) {
            ForEach(inventoryViewModel.authorGroupingForType(.books), id: \.0) { author, authorItems in
                NavigationLink {
                    BooksByAuthorView(author: author)
                } label: {
                    AuthorGroupRow(
                        author: author, 
                        itemCount: authorItems.count,
                        terminology: type.authorGroupingTerminology
                    )
                }
            }
        }
    }
    
    private func seriesListView(for collectionType: CollectionType) -> some View {
        List(selection: $selectedItems) {
            ForEach(inventoryViewModel.seriesForType(collectionType), id: \.0) { series, seriesItems in
                NavigationLink {
                    SeriesDetailView(series: series, collectionType: collectionType)
                } label: {
                    SeriesGroupRow(
                        series: series, 
                        itemCount: seriesItems.count,
                        terminology: collectionType.seriesItemTerminology
                    )
                }
            }
        }
    }
    
    private func seriesCardView(for collectionType: CollectionType) -> some View {
        let allItems = inventoryViewModel.seriesForType(collectionType).flatMap { $0.1 }
        return CardGridView(items: allItems, showSeriesGrouping: true)
            .environmentObject(inventoryViewModel)
            .environmentObject(locationManager)
    }
    
    private var itemsListView: some View {
        List(selection: $selectedItems) {
            ForEach(items.sorted { $0.title < $1.title }) { item in
                NavigationLink {
                    ItemDetailView(item: item)
                } label: {
                    ItemRow(item: item)
                }
            }
        }
    }
    
    private var itemsCardView: some View {
        CardGridView(items: items.sorted { $0.title < $1.title }, showSeriesGrouping: false)
            .environmentObject(inventoryViewModel)
            .environmentObject(locationManager)
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
    let terminology: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(series)
                .font(.headline)
            Text("\(itemCount) \(terminology)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

/// Displays an author group with consistent styling
struct AuthorGroupRow: View {
    let author: String
    let itemCount: Int
    let terminology: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(author)
                .font(.headline)
            Text("\(itemCount) \(terminology)")
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