import SwiftUI

struct AddItemView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.dismiss) var dismiss
    @State private var showingError = false
    @State private var errorMessage = ""
    
    @State private var title = ""
    @State private var type: CollectionType = .books
    @State private var series = ""
    @State private var volume = ""
    @State private var condition: ItemCondition = .good
    @State private var selectedLocationId: UUID?
    @State private var notes = ""
    @State private var showingLocationPicker = false
    
    var selectedLocation: StorageLocation? {
        guard let id = selectedLocationId else { return nil }
        return locationManager.location(withId: id)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Item Details") {
                    TextField("Title", text: $title)
                    Picker("Type", selection: $type) {
                        ForEach(CollectionType.allCases) { type in
                            Text(type.name).tag(type)
                        }
                    }
                    TextField("Series", text: $series)
                    TextField("Volume", text: $volume)
                        .keyboardType(.numberPad)
                }
                
                Section("Additional Info") {
                    Picker("Condition", selection: $condition) {
                        ForEach(ItemCondition.allCases, id: \.self) { condition in
                            Text(condition.rawValue).tag(condition)
                        }
                    }
                    TextField("Notes", text: $notes)
                }
                
                Section("Location") {
                    Button {
                        showingLocationPicker = true
                    } label: {
                        HStack {
                            Text("Location")
                            Spacer()
                            if let location = selectedLocation {
                                Text(location.name)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Select")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Item")
            .sheet(isPresented: $showingLocationPicker) {
                NavigationView {
                    LocationPicker(selectedLocationId: $selectedLocationId)
                        .environmentObject(locationManager)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveItem()
                    }
                    .disabled(title.isEmpty)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func saveItem() {
        let item = InventoryItem(
            title: title,
            type: type,
            series: series.isEmpty ? nil : series,
            volume: Int(volume),
            condition: condition,
            locationId: selectedLocationId,
            notes: notes
        )
        
        do {
            try inventoryViewModel.addItem(item)
            inventoryViewModel.saveItems() // Save after successful add
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
} 