import SwiftUI

struct EditItemView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var locationManager: LocationManager
    
    let item: InventoryItem
    @State private var editedItem: InventoryItem
    @State private var showingError = false
    @State private var errorMessage = ""
    
    init(item: InventoryItem) {
        self.item = item
        _editedItem = State(initialValue: item)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Details") {
                    TextField("Title", text: $editedItem.title)
                    
                    if editedItem.type.isLiterature {
                        TextField("Author", text: Binding(
                            get: { editedItem.author ?? "" },
                            set: { editedItem.author = $0.isEmpty ? nil : $0 }
                        ))
                    } else {
                        TextField("Manufacturer", text: Binding(
                            get: { editedItem.manufacturer ?? "" },
                            set: { editedItem.manufacturer = $0.isEmpty ? nil : $0 }
                        ))
                    }
                    
                    Picker("Condition", selection: $editedItem.condition) {
                        ForEach(ItemCondition.allCases, id: \.self) { condition in
                            Text(condition.rawValue).tag(condition)
                        }
                    }
                }
                
                Section("Location") {
                    LocationPickerView(selectedLocationId: $editedItem.locationId)
                }
                
                Section("Dates") {
                    DatePicker("Purchase Date", 
                             selection: Binding(
                                get: { editedItem.purchaseDate ?? Date() },
                                set: { editedItem.purchaseDate = $0 }
                             ),
                             displayedComponents: .date)
                    
                    if editedItem.type.isLiterature {
                        DatePicker("Original Publish Date",
                                 selection: Binding(
                                    get: { editedItem.originalPublishDate ?? Date() },
                                    set: { editedItem.originalPublishDate = $0 }
                                 ),
                                 displayedComponents: .date)
                    }
                }
                
                Section("Additional Details") {
                    TextField("Price", value: Binding(
                        get: { editedItem.price ?? 0 },
                        set: { editedItem.price = $0 }
                    ), format: .currency(code: "USD"))
                    
                    TextField("Synopsis", text: Binding(
                        get: { editedItem.synopsis ?? "" },
                        set: { editedItem.synopsis = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                    .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveItem()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func saveItem() {
        do {
            try inventoryViewModel.updateItem(editedItem)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
} 