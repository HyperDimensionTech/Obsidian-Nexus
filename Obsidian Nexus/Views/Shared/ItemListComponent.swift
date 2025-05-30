import SwiftUI

/**
 A reusable component for displaying and organizing lists of inventory items.
 
 This component provides a standardized way to display item collections with various
 grouping options, sort styles, and layout configurations.
 
 ## Usage
 
 ```swift
 // Basic usage with default settings
 ItemListComponent(items: viewModel.items)
 
 // With section title
 ItemListComponent(
     items: viewModel.items,
     sectionTitle: "My Items"
 )
 
 // With grouping by location
 ItemListComponent(
     items: viewModel.items,
     groupingStyle: .byLocation
 )
 
 // With custom sorting
 ItemListComponent(
     items: viewModel.items,
     sortStyle: .byTitle
 )
 
 // With navigation coordinator
 ItemListComponent(
     items: viewModel.items,
     useCoordinator: true
 )
 ```
 
 ## Grouping Styles
 
 - `.none`: No grouping, displays items in a single list (default)
 - `.byLocation`: Groups items by their storage location
 - `.byType`: Groups items by their type (Book, Manga, etc)
 - `.bySeries`: Groups items by their series name
 
 ## Sort Styles
 
 - `.byTitle`: Sorts items alphabetically by title (default)
 - `.byType`: Sorts items by type, then by title
 - `.byLocation`: Sorts items by location, then by title
 - `.bySeries`: Sorts items by series, then by volume
 
 ## Environment Requirements
 
 This component requires the following environment objects:
 - `@EnvironmentObject var locationManager: LocationManager`
 - `@EnvironmentObject var userPreferences: UserPreferences`
 - `@EnvironmentObject var navigationCoordinator: NavigationCoordinator` (when `useCoordinator` is true)
 */
struct ItemListComponent: View {
    // MARK: - Environment
    
    @EnvironmentObject private var inventoryViewModel: InventoryViewModel
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    
    // MARK: - Properties
    
    /// The items to display in the list
    let items: [InventoryItem]
    
    /// The title for the list section
    var sectionTitle: String?
    
    /// How to group the items
    var groupingStyle: GroupingStyle = .none
    
    /// How to sort the items
    var sortStyle: SortStyle = .title
    
    /// Whether to enable selection mode
    var enableSelection: Bool = true
    
    /// Whether to enable editing mode
    var enableEditing: Bool = true
    
    /// Whether to use NavigationCoordinator instead of NavigationLink
    var useCoordinator: Bool = false
    
    /// Optional binding to parent's edit mode to prevent duplicate UI controls
    var parentEditMode: Binding<EditMode>? = nil
    
    /// Optional binding to parent's selection state
    var parentSelection: Binding<Set<UUID>>? = nil
    
    // MARK: - State
    
    @State private var selectedItems: Set<UUID> = []
    @State private var isEditMode: EditMode = .inactive
    @State private var showingBulkEditSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteError = false
    @State private var deleteErrorMessage = ""
    
    // MARK: - Computed Properties
    
    /// The sorted and grouped items based on the chosen styles
    private var organizedItems: [ItemGroup] {
        switch groupingStyle {
        case .none:
            let sortedItems = sortItems(items)
            return [ItemGroup(title: sectionTitle ?? "Items", items: sortedItems)]
            
        case .byType:
            // Group items by their collection type
            let grouped = Dictionary(grouping: items) { $0.type }
            return grouped
                .map { type, typeItems in
                    ItemGroup(title: type.name, items: sortItems(typeItems))
                }
                .sorted { $0.title < $1.title }
            
        case .bySeries:
            // Group manga/comics by series
            let grouped = Dictionary(grouping: items) { $0.series ?? "Uncategorized" }
            return grouped
                .map { series, seriesItems in
                    ItemGroup(title: series, items: sortItems(seriesItems))
                }
                .sorted { $0.title < $1.title }
            
        case .byAuthor:
            // Group books by author
            let grouped = Dictionary(grouping: items) { $0.author ?? "Unknown Author" }
            return grouped
                .map { author, authorItems in
                    ItemGroup(title: author, items: sortItems(authorItems))
                }
                .sorted { $0.title < $1.title }
            
        case .byLocation:
            // Group by location
            return groupByLocation(items)
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        if !items.isEmpty {
            List(selection: enableSelection ? (parentSelection ?? $selectedItems) : nil) {
                ForEach(organizedItems) { group in
                    Section(header: Text(group.title)) {
                        ForEach(group.items) { item in
                            if useCoordinator {
                                Button {
                                    navigationCoordinator.navigateToItemDetail(item: item)
                                } label: {
                                    ItemRow(item: item)
                                }
                            } else {
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
            .environment(\.editMode, parentEditMode ?? (enableEditing ? $isEditMode : .constant(.inactive)))
            .onChange(of: isEditMode) { _, newValue in
                if newValue == .inactive {
                    if let parentSelection = parentSelection {
                        parentSelection.wrappedValue.removeAll()
                    } else {
                        selectedItems.removeAll()
                    }
                }
            }
            .toolbar {
                // Only show toolbar items if parentEditMode is nil to prevent duplicates
                if enableEditing && parentEditMode == nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if isEditMode == .inactive {
                            Button("Select") {
                                isEditMode = .active
                            }
                        } else {
                            Menu {
                                Button("Edit Selected (\(parentSelection?.wrappedValue.count ?? selectedItems.count))") {
                                    showingBulkEditSheet = true
                                }
                                .disabled((parentSelection?.wrappedValue.isEmpty ?? selectedItems.isEmpty))
                                
                                Button("Select All") {
                                    if let parentSelection = parentSelection {
                                        parentSelection.wrappedValue = Set(items.map { $0.id })
                                    } else {
                                        selectedItems = Set(items.map { $0.id })
                                    }
                                }
                                
                                Button("Delete Selected", role: .destructive) {
                                    showingDeleteConfirmation = true
                                }
                                .disabled((parentSelection?.wrappedValue.isEmpty ?? selectedItems.isEmpty))
                                
                                Button("Done") {
                                    isEditMode = .inactive
                                    if let parentSelection = parentSelection {
                                        parentSelection.wrappedValue.removeAll()
                                    } else {
                                        selectedItems.removeAll()
                                    }
                                }
                            } label: {
                                Text("Edit")
                            }
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
                Text("Are you sure you want to delete \(parentSelection?.wrappedValue.count ?? selectedItems.count) items? This action cannot be undone.")
            }
            .alert("Delete Error", isPresented: $showingDeleteError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(deleteErrorMessage)
            }
            .sheet(isPresented: $showingBulkEditSheet) {
                NavigationStack {
                    EditItemView(items: inventoryViewModel.items.filter { (parentSelection?.wrappedValue ?? selectedItems).contains($0.id) })
                        .environmentObject(inventoryViewModel)
                        .environmentObject(locationManager)
                }
            }
        } else {
            emptyStateView
        }
    }
    
    // MARK: - Supporting Views
    
    private var emptyStateView: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 24) {
                Image(systemName: "tray")
                    .font(.system(size: 70))
                    .foregroundStyle(.tertiary)
                    .symbolRenderingMode(.hierarchical)
                    .accessibilityHidden(true)
                
                VStack(spacing: 8) {
                    Text("No Items")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Add items to your collection to see them here")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 250)
                }
            }
            .padding(.bottom, 40)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No items in collection")
    }
    
    // MARK: - Helper Methods
    
    /// Sorts items based on the chosen sort style
    private func sortItems(_ itemsToSort: [InventoryItem]) -> [InventoryItem] {
        switch sortStyle {
        case .title:
            return itemsToSort.sorted { $0.title < $1.title }
            
        case .dateAdded:
            return itemsToSort.sorted { $0.dateAdded > $1.dateAdded }
            
        case .price:
            return itemsToSort.sorted {
                let price1 = $0.price?.amount ?? 0
                let price2 = $1.price?.amount ?? 0
                return price1 > price2
            }
            
        case .volume:
            return itemsToSort.sorted {
                let vol1 = $0.volume ?? 0
                let vol2 = $1.volume ?? 0
                return vol1 < vol2
            }
        }
    }
    
    /// Groups items by their location hierarchy
    private func groupByLocation(_ itemsToGroup: [InventoryItem]) -> [ItemGroup] {
        let itemsByLocation = Dictionary(grouping: itemsToGroup) { item -> String in
            guard let locationId = item.locationId,
                  let location = locationManager.location(withId: locationId) else {
                return "No Location"
            }
            let path = locationManager.breadcrumbPath(for: locationId)
            return path.isEmpty ? location.name : path
        }
        
        return itemsByLocation
            .map { location, locationItems in
                ItemGroup(title: location, items: sortItems(locationItems))
            }
            .sorted { $0.title < $1.title }
    }
    
    /// Deletes the selected items
    private func deleteSelectedItems() {
        let itemsToDelete = parentSelection?.wrappedValue ?? selectedItems
        do {
            try inventoryViewModel.bulkDeleteItems(with: itemsToDelete)
            if let parentSelection = parentSelection {
                parentSelection.wrappedValue.removeAll()
            } else {
                selectedItems.removeAll()
            }
            isEditMode = .inactive
        } catch {
            deleteErrorMessage = error.localizedDescription
            showingDeleteError = true
        }
    }
}

// MARK: - Supporting Types

extension ItemListComponent {
    /// Represents a group of items with a title
    struct ItemGroup: Identifiable {
        let id = UUID()
        let title: String
        let items: [InventoryItem]
    }
    
    /// How to group the items in the list
    enum GroupingStyle {
        /// No grouping, show as a flat list
        case none
        
        /// Group by collection type
        case byType
        
        /// Group by series (for manga, comics)
        case bySeries
        
        /// Group by author (for books)
        case byAuthor
        
        /// Group by location
        case byLocation
    }
    
    /// How to sort the items in the list
    enum SortStyle {
        /// Sort alphabetically by title
        case title
        
        /// Sort by date added (newest first)
        case dateAdded
        
        /// Sort by price (highest first)
        case price
        
        /// Sort by volume number (lowest first)
        case volume
    }
}

// Simple empty preview that doesn't try to create real data or models
struct ItemListComponent_Previews: PreviewProvider {
    static var previews: some View {
        Text("Item List Component Preview Disabled")
            .padding()
    }
}
