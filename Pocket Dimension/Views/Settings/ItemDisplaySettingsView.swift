import SwiftUI

// Move example items to a separate helper struct
private struct ExampleItems {
    // Create mock locations that will always be available for preview
    static let livingRoomId = UUID()
    static let mangaShelfId = UUID()
    static let onePieceBoxId = UUID()
    
    static var mockLocations: [UUID: StorageLocation] {
        [
            livingRoomId: StorageLocation(id: livingRoomId, name: "Living Room", type: .room),
            mangaShelfId: StorageLocation(id: mangaShelfId, name: "Manga Shelf", type: .bookshelf, parentId: livingRoomId),
            onePieceBoxId: StorageLocation(id: onePieceBoxId, name: "One Piece Collection Box", type: .box, parentId: mangaShelfId)
        ]
    }
    
    static func getItems() -> [InventoryItem] {
        let item1 = InventoryItem(
            title: "One Piece, Vol. 31",
            type: .manga,
            series: "One Piece",
            volume: 31,
            condition: .good,
            locationId: onePieceBoxId,
            price: Price(amount: 9.99, currency: .usd)
        )
        
        let item2 = InventoryItem(
            title: "Demon Slayer, Vol. 5",
            type: .manga,
            series: "Demon Slayer",
            volume: 5,
            condition: .likeNew,
            locationId: mangaShelfId,
            price: Price(amount: 14.99, currency: .usd)
        )
        
        return [item1, item2]
    }
}

// A simplified mock LocationManager just for previews
private class MockLocationManager: ObservableObject {
    // Mock the functionality we need for display
    func location(withId id: UUID) -> StorageLocation? {
        return ExampleItems.mockLocations[id]
    }
    
    func breadcrumbPath(for id: UUID) -> String? {
        if id == ExampleItems.onePieceBoxId {
            return "Living Room > Manga Shelf > One Piece Collection Box"
        } else if id == ExampleItems.mangaShelfId {
            return "Living Room > Manga Shelf"
        }
        return "Unknown Location"
    }
}

struct ItemDisplaySettingsView: View {
    @EnvironmentObject private var userPreferences: UserPreferences
    @State private var selectedOptions: [UserPreferences.ItemInfoDisplayOption]
    @State private var showReorderHelper = false
    
    // Use the helper to get example items
    private var exampleItems: [InventoryItem] {
        ExampleItems.getItems()
    }
    
    init() {
        // This allows us to have a local copy to manipulate before saving
        _selectedOptions = State(initialValue: UserPreferences().itemInfoDisplayOptions)
    }
    
    var body: some View {
        List {
            instructionsSection
            displayOptionsSection
            
            if !selectedOptions.isEmpty {
                reorderSection
            }
            
            previewSection
        }
        .navigationTitle("Item Display")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    userPreferences.itemInfoDisplayOptions = selectedOptions
                }
                .disabled(selectedOptions == userPreferences.itemInfoDisplayOptions)
            }
        }
        .onAppear {
            // Initialize with current preferences
            selectedOptions = userPreferences.itemInfoDisplayOptions
        }
    }
    
    // Break up complex sections into separate view properties
    private var instructionsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose what information to display beneath each item in your collection.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Information will be displayed in the order selected below.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
                
                if showReorderHelper {
                    Text("Tap and hold an option to drag and reorder")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                        .padding(.top, 2)
                }
            }
            .padding(.vertical, 6)
        }
    }
    
    private var displayOptionsSection: some View {
        Section("Display Options") {
            ForEach(UserPreferences.ItemInfoDisplayOption.allCases, id: \.self) { option in
                Toggle(isOn: toggleBinding(for: option)) {
                    Text(option.rawValue)
                }
            }
        }
    }
    
    private var reorderSection: some View {
        Section(header: Text("DISPLAY ORDER"), footer: Text("Drag to reorder which information appears first")) {
            if showReorderHelper {
                Text("Tap and hold an option to drag and reorder")
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    .padding(.vertical, 4)
            }
            
            Button("Show Reorder Help") {
                showReorderHelper.toggle()
            }
            .padding(.bottom, 8)
            
            ForEach(selectedOptions, id: \.self) { option in
                HStack {
                    Text(option.rawValue)
                    Spacer()
                    Image(systemName: "line.3.horizontal")
                        .foregroundColor(.secondary)
                }
            }
            .onMove { from, to in
                selectedOptions.move(fromOffsets: from, toOffset: to)
            }
        }
        .environment(\.editMode, .constant(.active))
    }
    
    private var previewSection: some View {
        Section("Preview") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Items will appear like this:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Wrap in a view that provides the mock location manager
                PreviewItemsView(items: exampleItems, displayOptions: selectedOptions)
            }
            .padding(.vertical, 6)
        }
    }
    
    // Helper function to create toggle bindings
    private func toggleBinding(for option: UserPreferences.ItemInfoDisplayOption) -> Binding<Bool> {
        Binding(
            get: { selectedOptions.contains(option) },
            set: { isOn in
                if isOn {
                    if !selectedOptions.contains(option) {
                        selectedOptions.append(option)
                    }
                } else {
                    selectedOptions.removeAll { $0 == option }
                }
            }
        )
    }
}

// A view that provides the mock location manager
private struct PreviewItemsView: View {
    let items: [InventoryItem]
    let displayOptions: [UserPreferences.ItemInfoDisplayOption]
    
    // Create a mock location manager
    @StateObject private var mockLocationManager = MockLocationManager()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                MockItemDisplayComponent(
                    item: item,
                    displayOptions: displayOptions,
                    locationManager: mockLocationManager
                )
                .padding(.vertical, 4)
                
                // Add divider after all except the last item
                if index < items.count - 1 {
                    Divider()
                }
            }
        }
    }
}

// A simplified version of ItemDisplayComponent that uses our mock location manager
private struct MockItemDisplayComponent: View {
    let item: InventoryItem
    let displayOptions: [UserPreferences.ItemInfoDisplayOption]
    let locationManager: MockLocationManager
    
    var displayStyle: DisplayStyle = .normal
    var showFullLocationPath: Bool = false
    
    // Define the display style enum within our component
    enum DisplayStyle {
        case normal
        case compact
        case detailed
        
        var spacing: CGFloat {
            switch self {
            case .normal: return 4
            case .compact: return 2
            case .detailed: return 8
            }
        }
        
        var titleFont: Font {
            switch self {
            case .normal: return .headline
            case .compact: return .subheadline
            case .detailed: return .title3
            }
        }
        
        var titleLineLimit: Int {
            switch self {
            case .normal: return 2
            case .compact: return 1
            case .detailed: return 3
            }
        }
        
        var metadataFont: Font {
            switch self {
            case .normal, .detailed: return .subheadline
            case .compact: return .caption
            }
        }
    }
    
    // Get location info from our mock manager
    private var location: StorageLocation? {
        guard let id = item.locationId else { return nil }
        return locationManager.location(withId: id)
    }
    
    private var locationPath: String? {
        guard let id = item.locationId else { return nil }
        return showFullLocationPath ? locationManager.breadcrumbPath(for: id) : location?.name
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: displayStyle.spacing) {
            // Title
            Text(item.title)
                .font(displayStyle.titleFont)
                .lineLimit(displayStyle.titleLineLimit)
            
            // Secondary information (type, location, price)
            if !displayOptions.isEmpty {
                HStack(spacing: 4) {
                    // Build secondary info based on display preferences
                    ForEach(displayOptions.indices, id: \.self) { index in
                        let option = displayOptions[index]
                        
                        // Only add separator if there's a previous visible item
                        if index > 0 && hasVisibleInfo(forOption: displayOptions[index - 1]) {
                            if hasVisibleInfo(forOption: option) {
                                Text("•")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                        
                        // Display the requested info if available
                        if hasVisibleInfo(forOption: option) {
                            Text(infoText(for: option))
                                .font(displayStyle.metadataFont)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    // Check if the info for a specific option is available
    private func hasVisibleInfo(forOption option: UserPreferences.ItemInfoDisplayOption) -> Bool {
        switch option {
        case .type:
            return true // Type is always available
        case .location:
            return locationPath != nil
        case .price:
            return item.price != nil
        case .none:
            return false
        }
    }
    
    // Get the text to display for a specific option
    private func infoText(for option: UserPreferences.ItemInfoDisplayOption) -> String {
        switch option {
        case .type:
            return item.type.name
        case .location:
            return locationPath ?? ""
        case .price:
            if let price = item.price {
                return price.formatted()
            }
            return ""
        case .none:
            return ""
        }
    }
}

#Preview {
    NavigationView {
        ItemDisplaySettingsView()
            .environmentObject(UserPreferences())
    }
} 