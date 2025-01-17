import SwiftUI

struct AddItemsToLocationView: View {
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var locationManager: LocationManager
    
    let locationId: UUID
    
    @State private var selectedItems: Set<UUID> = []
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingSuccessMessage = false
    
    private var location: StorageLocation? {
        locationManager.location(withId: locationId)
    }
    
    private var availableItems: [InventoryItem] {
        inventoryViewModel.items.filter { $0.locationId != locationId }
    }
    
    var body: some View {
        List {
            if availableItems.isEmpty {
                Text("No items available to add")
                    .foregroundColor(.secondary)
            } else {
                ForEach(availableItems) { item in
                    ItemSelectionRow(item: item, isSelected: selectedItems.contains(item.id)) {
                        if selectedItems.contains(item.id) {
                            selectedItems.remove(item.id)
                        } else {
                            selectedItems.insert(item.id)
                        }
                    }
                }
            }
        }
        .navigationTitle("Add Items")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Confirm") {
                    updateItemLocations()
                }
                .disabled(selectedItems.isEmpty)
            }
            
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .overlay {
            if showingSuccessMessage {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("\(selectedItems.count) items moved to \(location?.name ?? "location")")
                    }
                    .padding()
                    .background(.thinMaterial)
                    .cornerRadius(10)
                    .padding(.bottom, 32)
                }
            }
        }
    }
    
    private func updateItemLocations() {
        guard !selectedItems.isEmpty else { return }
        guard locationManager.validateLocationId(locationId) else {
            errorMessage = "Invalid location selected"
            showingError = true
            return
        }
        
        do {
            try inventoryViewModel.updateItemLocations(items: selectedItems, to: locationId)
            showSuccessAndDismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func showSuccessAndDismiss() {
        showingSuccessMessage = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            navigationCoordinator.dismissSheet()
            navigationCoordinator.navigate(to: .locationDetail(location!))
        }
    }
}

// Helper view for item selection
struct ItemSelectionRow: View {
    let item: InventoryItem
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(item.title)
                        .font(.headline)
                    if let series = item.series {
                        Text(series)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationView {
        AddItemsToLocationView(locationId: UUID())
            .environmentObject(InventoryViewModel(locationManager: LocationManager()))
            .environmentObject(LocationManager())
    }
} 