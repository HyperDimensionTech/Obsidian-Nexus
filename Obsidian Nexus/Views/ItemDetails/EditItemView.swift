import SwiftUI

struct EditItemView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var userPreferences: UserPreferences
    
    // Support both single and multiple items
    let items: [InventoryItem]
    @State private var editedItem: InventoryItem
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var fieldsToUpdate: Set<String> = []
    @State private var updateProgress: Double = 0
    @State private var isUpdating = false
    @State private var purchaseDate = Date()
    @State private var priceAmount: String = ""
    @State private var selectedCurrency: Price.Currency
    @State private var selectedType: CollectionType
    
    // Add convenience initializer for single item
    init(item: InventoryItem) {
        self.items = [item]
        _editedItem = State(initialValue: item)
        _selectedType = State(initialValue: item.type)
        
        // Initialize currency from item if available, will be updated in onAppear if needed
        if let price = item.price {
            _selectedCurrency = State(initialValue: price.currency)
        } else {
            _selectedCurrency = State(initialValue: .usd) // Default, will be updated in onAppear
        }
    }
    
    // Existing initializer for bulk editing
    init(items: [InventoryItem]) {
        self.items = items
        _editedItem = State(initialValue: items.first ?? InventoryItem(title: "", type: .books))
        _selectedType = State(initialValue: items.first?.type ?? .books)
        
        // Initialize with a default currency, will be updated in onAppear
        _selectedCurrency = State(initialValue: .usd)
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
            
            Section("Purchase Information") {
                // Toggle for price updates (for both single and bulk edits)
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
                    HStack {
                        TextField("Price", text: $priceAmount)
                            .keyboardType(.decimalPad)
                        Picker("Currency", selection: $selectedCurrency) {
                            ForEach(Price.Currency.allCases, id: \.self) { currency in
                                Text(currency.code).tag(currency)
                            }
                        }
                    }
                    DatePicker("Purchase Date", selection: $purchaseDate, displayedComponents: .date)
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
                .disabled(isBulkEditing && fieldsToUpdate.isEmpty)
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            // Set price amount from existing item if available
            if let price = editedItem.price {
                priceAmount = price.amount.formatted()
                selectedCurrency = price.currency
            } else {
                // Set default currency from user preferences if no price exists
                selectedCurrency = userPreferences.defaultCurrency
            }
            
            // Set purchase date from existing item
            if let date = editedItem.purchaseDate {
                purchaseDate = date
            }
        }
    }
    
    private func saveChanges() {
        let price: Price?
        if let amount = Decimal(string: priceAmount), Price.isValid(amount) {
            price = Price(amount: amount, currency: selectedCurrency)
        } else {
            price = nil
        }
        
        if isBulkEditing {
            // For bulk editing, only update fields that are marked to be updated
            let updatedItem = InventoryItem(
                title: editedItem.title,
                type: fieldsToUpdate.contains("type") ? selectedType : editedItem.type,
                series: editedItem.series,
                volume: editedItem.volume,
                condition: fieldsToUpdate.contains("condition") ? editedItem.condition : editedItem.condition,
                locationId: fieldsToUpdate.contains("location") ? editedItem.locationId : nil,
                notes: editedItem.notes,
                id: editedItem.id,
                dateAdded: editedItem.dateAdded,
                barcode: editedItem.barcode,
                thumbnailURL: editedItem.thumbnailURL,
                author: fieldsToUpdate.contains("author") ? editedItem.author : nil,
                manufacturer: editedItem.manufacturer,
                originalPublishDate: editedItem.originalPublishDate,
                publisher: editedItem.publisher,
                isbn: editedItem.isbn,
                price: fieldsToUpdate.contains("price") ? price : nil,
                purchaseDate: fieldsToUpdate.contains("price") ? purchaseDate : nil,
                synopsis: editedItem.synopsis,
                customImageData: fieldsToUpdate.contains("image") ? editedItem.customImageData : nil,
                imageSource: fieldsToUpdate.contains("image") ? 
                    (editedItem.customImageData != nil ? .custom : .none) : .none
            )
            
            do {
                // Update items and ensure UI refresh
                try inventoryViewModel.bulkUpdateItems(items: items, updates: updatedItem, fields: fieldsToUpdate)
                
                // Explicitly force a reload of all items to update the view model
                inventoryViewModel.refreshItems()
                
                // Return to previous view
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        } else {
            // For single item editing, preserve existing values for fields not being edited
            var updatedItem = editedItem
            
            // Always update type for single items when selectedType is changed
            updatedItem.type = selectedType
            
            // Only update price and purchase date if the field is toggled
            if fieldsToUpdate.contains("price") {
                updatedItem.price = price
                updatedItem.purchaseDate = purchaseDate
            }
            
            // Only update these fields if they're in fieldsToUpdate
            if fieldsToUpdate.contains("image") {
                updatedItem.customImageData = editedItem.customImageData
                updatedItem.imageSource = editedItem.customImageData != nil ? .custom : .none
            }
            
            if fieldsToUpdate.contains("condition") {
                updatedItem.condition = editedItem.condition
            }
            
            if fieldsToUpdate.contains("location") {
                updatedItem.locationId = editedItem.locationId
            }
            
            // Only update author if the field is toggled
            if editedItem.type.isLiterature && fieldsToUpdate.contains("author") {
                updatedItem.author = editedItem.author
            }
            
            do {
                // Update the item
                try inventoryViewModel.updateItem(updatedItem)
                
                // Explicitly force a reload of all items to update the view model
                inventoryViewModel.refreshItems()
                
                // Return to previous view
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
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