import SwiftUI

struct EditItemView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var locationManager: LocationManager
    
    // Support both single and multiple items
    let items: [InventoryItem]
    @State private var editedItem: InventoryItem
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var fieldsToUpdate: Set<String> = []
    @State private var updateProgress: Double = 0
    @State private var isUpdating = false
    @State private var purchaseDate = Date()
    @State private var price: String = ""
    @State private var selectedType: CollectionType
    
    // Add convenience initializer for single item
    init(item: InventoryItem) {
        self.items = [item]
        _editedItem = State(initialValue: item)
        _selectedType = State(initialValue: item.type)
    }
    
    // Existing initializer for bulk editing
    init(items: [InventoryItem]) {
        self.items = items
        _editedItem = State(initialValue: items.first ?? InventoryItem(title: "", type: .books))
        _selectedType = State(initialValue: items.first?.type ?? .books)
    }
    
    var isBulkEditing: Bool {
        items.count > 1
    }
    
    var body: some View {
        Form {
            if isBulkEditing {
                Section("Bulk Editing \(items.count) Items") {
                    Text("Only selected fields will be updated")
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Image") {
                Toggle("Update Image", isOn: Binding(
                    get: { fieldsToUpdate.contains("image") },
                    set: { newValue in
                        if newValue {
                            fieldsToUpdate.insert("image")
                        } else {
                            fieldsToUpdate.remove("image")
                        }
                    }
                ))
                
                if fieldsToUpdate.contains("image") {
                    ItemImagePicker(imageData: $editedItem.customImageData)
                }
            }
            
            Section("Basic Information") {
                Toggle("Update Type", isOn: Binding(
                    get: { fieldsToUpdate.contains("type") },
                    set: { newValue in
                        if newValue {
                            fieldsToUpdate.insert("type")
                        } else {
                            fieldsToUpdate.remove("type")
                        }
                    }
                ))
                
                if fieldsToUpdate.contains("type") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(CollectionType.allCases) { type in
                            Text(type.name).tag(type)
                        }
                    }
                }
                
                // Add Author Toggle and TextField
                if selectedType.isLiterature {
                    Toggle("Update Author", isOn: Binding(
                        get: { fieldsToUpdate.contains("author") },
                        set: { newValue in
                            if newValue {
                                fieldsToUpdate.insert("author")
                            } else {
                                fieldsToUpdate.remove("author")
                            }
                        }
                    ))
                    
                    if fieldsToUpdate.contains("author") {
                        TextField("Author", text: Binding(
                            get: { editedItem.author ?? "" },
                            set: { editedItem.author = $0.isEmpty ? nil : $0 }
                        ))
                        .textContentType(.name)
                        .autocapitalization(.words)
                        
                        Text("For multiple authors, separate with commas")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Toggle("Update Location", isOn: Binding(
                    get: { fieldsToUpdate.contains("location") },
                    set: { newValue in
                        if newValue {
                            fieldsToUpdate.insert("location")
                        } else {
                            fieldsToUpdate.remove("location")
                        }
                    }
                ))
                
                if fieldsToUpdate.contains("location") {
                    LocationPicker(selectedLocationId: $editedItem.locationId)
                        .navigationTitle("Select Location")
                }
            }
            
            Section("Purchase Info") {
                Toggle("Update Price", isOn: Binding(
                    get: { fieldsToUpdate.contains("price") },
                    set: { newValue in
                        if newValue {
                            fieldsToUpdate.insert("price")
                        } else {
                            fieldsToUpdate.remove("price")
                        }
                    }
                ))
                if fieldsToUpdate.contains("price") {
                    TextField("Price", text: $price)
                        .keyboardType(.decimalPad)
                }
                
                Toggle("Update Purchase Date", isOn: Binding(
                    get: { fieldsToUpdate.contains("purchaseDate") },
                    set: { newValue in
                        if newValue {
                            fieldsToUpdate.insert("purchaseDate")
                        } else {
                            fieldsToUpdate.remove("purchaseDate")
                        }
                    }
                ))
                if fieldsToUpdate.contains("purchaseDate") {
                    DatePicker("Purchase Date", 
                             selection: $purchaseDate,
                             displayedComponents: .date)
                }
            }
            
            Section("Condition") {
                Toggle("Update Condition", isOn: Binding(
                    get: { fieldsToUpdate.contains("condition") },
                    set: { newValue in
                        if newValue {
                            fieldsToUpdate.insert("condition")
                        } else {
                            fieldsToUpdate.remove("condition")
                        }
                    }
                ))
                if fieldsToUpdate.contains("condition") {
                    Picker("Condition", selection: $editedItem.condition) {
                        ForEach(ItemCondition.allCases, id: \.self) { condition in
                            Text(condition.rawValue).tag(condition)
                        }
                    }
                }
            }
            
            // Add other bulk-editable fields as needed...
        }
        .navigationTitle(isBulkEditing ? "Bulk Edit" : "Edit Item")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveChanges()
                }
                .disabled(isBulkEditing ? fieldsToUpdate.isEmpty : false)
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func saveChanges() {
        do {
            let updates = InventoryItem(
                title: editedItem.title,
                type: fieldsToUpdate.contains("type") ? selectedType : editedItem.type,
                condition: editedItem.condition,
                locationId: fieldsToUpdate.contains("location") ? editedItem.locationId : nil,
                price: fieldsToUpdate.contains("price") ? Decimal(string: price) : nil,
                purchaseDate: fieldsToUpdate.contains("purchaseDate") ? purchaseDate : nil,
                customImageData: fieldsToUpdate.contains("image") ? editedItem.customImageData : nil,
                imageSource: fieldsToUpdate.contains("image") ? 
                    (editedItem.customImageData != nil ? .custom : .none) : .none
            )
            
            if isBulkEditing {
                try inventoryViewModel.bulkUpdateItems(items: items, updates: updates, fields: fieldsToUpdate)
            } else {
                var updatedItem = editedItem
                if fieldsToUpdate.contains("type") {
                    updatedItem.type = selectedType
                }
                if fieldsToUpdate.contains("price") {
                    updatedItem.price = Decimal(string: price)
                }
                if fieldsToUpdate.contains("purchaseDate") {
                    updatedItem.purchaseDate = purchaseDate
                }
                if fieldsToUpdate.contains("location") {
                    updatedItem.locationId = editedItem.locationId
                }
                if fieldsToUpdate.contains("condition") {
                    updatedItem.condition = editedItem.condition
                }
                if fieldsToUpdate.contains("image") {
                    print("Image update requested")
                    print("Has image data: \(editedItem.customImageData != nil)")
                    print("Image source: \(editedItem.imageSource)")
                    updatedItem.customImageData = editedItem.customImageData
                    updatedItem.imageSource = editedItem.customImageData != nil ? .custom : .none
                }
                if fieldsToUpdate.contains("author") {
                    updatedItem.author = editedItem.author
                }
                try inventoryViewModel.updateItem(updatedItem)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func updateProgressView() -> some View {
        VStack {
            ProgressView(value: updateProgress)
            Text("\(Int(updateProgress * 100))% Complete")
        }
        .padding()
    }
}

extension Set {
    mutating func toggle(_ element: Element) {
        if contains(element) {
            remove(element)
        } else {
            insert(element)
        }
    }
} 