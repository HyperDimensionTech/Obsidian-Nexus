import SwiftUI

// Move example items to a separate helper struct
private struct ExampleItems {
    static func getItems() -> [InventoryItem] {
        let item1 = InventoryItem(
            title: "One Piece, Vol. 31",
            type: .manga,
            series: "One Piece",
            volume: 31,
            condition: .good,
            locationId: nil,
            price: Price(amount: 9.99, currency: .usd)
        )
        
        let item2 = InventoryItem(
            title: "Demon Slayer, Vol. 5",
            type: .manga,
            series: "Demon Slayer",
            volume: 5,
            condition: .likeNew,
            locationId: nil
        )
        
        return [item1, item2]
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
                
                ForEach(Array(exampleItems.enumerated()), id: \.element.id) { index, item in
                    PreviewItemRow(item: item, displayOptions: selectedOptions)
                        .padding(.vertical, 4)
                    
                    // Add divider after all except the last item
                    if index < exampleItems.count - 1 {
                        Divider()
                    }
                }
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

struct PreviewItemRow: View {
    let item: InventoryItem
    let displayOptions: [UserPreferences.ItemInfoDisplayOption]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(item.title)
                .font(.headline)
            
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
                            .font(.subheadline)
                            .foregroundColor(.secondary)
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
            return item.locationId != nil
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
            return item.locationId != nil ? "Sample Location" : ""
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