import SwiftUI

struct EditItemView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var userPreferences: UserPreferences
    
    let item: InventoryItem
    
    // Form state
    @State private var title: String
    @State private var author: String
    @State private var publisher: String
    @State private var isbn: String
    @State private var series: String
    @State private var volume: String
    @State private var condition: ItemCondition
    @State private var type: CollectionType
    @State private var locationId: UUID?
    @State private var notes: String
    @State private var barcode: String
    @State private var synopsis: String
    @State private var priceAmount: String
    @State private var selectedCurrency: Price.Currency
    @State private var purchaseDate: Date
    @State private var originalPublishDate: Date?
    @State private var showingDatePicker = false
    @State private var imageData: Data?
    @State private var showingImagePicker = false
    
    // UI state
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isSaving = false
    
    init(item: InventoryItem) {
        self.item = item
        _title = State(initialValue: item.title)
        _author = State(initialValue: item.author ?? "")
        _publisher = State(initialValue: item.publisher ?? "")
        _isbn = State(initialValue: item.isbn ?? "")
        _series = State(initialValue: item.series ?? "")
        _volume = State(initialValue: item.volume?.description ?? "")
        _condition = State(initialValue: item.condition)
        _type = State(initialValue: item.type)
        _locationId = State(initialValue: item.locationId)
        _notes = State(initialValue: item.notes ?? "")
        _barcode = State(initialValue: item.barcode ?? "")
        _synopsis = State(initialValue: item.synopsis ?? "")
        _priceAmount = State(initialValue: item.price?.amount.description ?? "")
        _selectedCurrency = State(initialValue: item.price?.currency ?? .usd)
        _purchaseDate = State(initialValue: item.purchaseDate ?? Date())
        _originalPublishDate = State(initialValue: item.originalPublishDate)
        _imageData = State(initialValue: item.customImageData)
    }
    
    var body: some View {
        NavigationView {
        Form {
                // Image Section
            Section("Image") {
                    HStack {
                        if let imageData = imageData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 80)
                                .cornerRadius(8)
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                        .font(.title2)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tap to change image")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            
                            Text("Select from gallery or take photo")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showingImagePicker = true
                    }
                }
                
                // Basic Information
                Section("Basic Information") {
                    TextField("Title", text: $title)
                        .textContentType(.name)
                    
                    Picker("Type", selection: $type) {
                        ForEach(CollectionType.allCases) { collectionType in
                            Text(collectionType.name).tag(collectionType)
                        }
                    }
                    
                    if type.isLiterature {
                        TextField("Author", text: $author)
                        .textContentType(.name)
                        .autocapitalization(.words)
                        
                        TextField("Publisher", text: $publisher)
                            .textContentType(.organizationName)
                            .autocapitalization(.words)
                        
                        TextField("ISBN", text: $isbn)
                            .textContentType(.none)
                            .autocapitalization(.none)
                        
                        TextField("Series", text: $series)
                            .textContentType(.none)
                            .autocapitalization(.words)
                        
                        TextField("Volume", text: $volume)
                            .keyboardType(.numberPad)
                    }
                    
                    Picker("Condition", selection: $condition) {
                        ForEach(ItemCondition.allCases, id: \.self) { condition in
                            Text(condition.rawValue.capitalized).tag(condition)
                        }
                    }
                }
                
                // Location Section
                Section("Location") {
                    ItemLocationPicker(selectedLocationId: $locationId)
                    
                    if let locationId = locationId,
                       let location = locationManager.getLocation(by: locationId) {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                            Text(location.name)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Remove") {
                                self.locationId = nil
                            }
                            .foregroundColor(.red)
                            .font(.caption)
                        }
                    }
                }
                
                // Additional Details
                Section("Additional Details") {
                    TextField("Barcode", text: $barcode)
                        .textContentType(.none)
                        .autocapitalization(.none)
                    
                    TextField("Synopsis", text: $synopsis, axis: .vertical)
                        .lineLimit(3...6)
                    
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                        }
                
                // Purchase Information
                Section("Purchase Information") {
                    HStack {
                        TextField("Price", text: $priceAmount)
                            .keyboardType(.decimalPad)
                        
                        Picker("Currency", selection: $selectedCurrency) {
                            ForEach(Price.Currency.allCases, id: \.self) { currency in
                                Text(currency.code).tag(currency)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    DatePicker("Purchase Date", selection: $purchaseDate, displayedComponents: .date)
                }
                
                // Publication Information
                if type.isLiterature {
                    Section("Publication Information") {
                        Button(action: {
                            showingDatePicker.toggle()
                        }) {
                            HStack {
                                Text("Original Publish Date")
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(originalPublishDate?.formatted(date: .abbreviated, time: .omitted) ?? "Not Set")
                                    .foregroundColor(.secondary)
                        }
                    }
                        
                        if showingDatePicker {
                            DatePicker("Select Date", selection: Binding(
                                get: { originalPublishDate ?? Date() },
                                set: { originalPublishDate = $0 }
                            ), displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            
                            Button("Clear Date") {
                                originalPublishDate = nil
                                showingDatePicker = false
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
        }
            .navigationTitle("Edit Item")
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
                    .disabled(title.isEmpty || isSaving)
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ItemImagePicker(imageData: $imageData)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
            }
        }
    }
    
    private func saveChanges() {
        guard !title.isEmpty else { return }
        
        isSaving = true
        
        // Create updated item with all changes
        let price: Price?
        if let amount = Decimal(string: priceAmount), Price.isValid(amount) {
            price = Price(amount: amount, currency: selectedCurrency)
        } else {
            price = nil
        }
        
            let updatedItem = InventoryItem(
            title: title,
            type: type,
            series: series.isEmpty ? nil : series,
            volume: Int(volume),
            condition: condition,
            locationId: locationId,
            notes: notes.isEmpty ? nil : notes,
            id: item.id,
            dateAdded: item.dateAdded,
            barcode: barcode.isEmpty ? nil : barcode,
            thumbnailURL: item.thumbnailURL,
            author: author.isEmpty ? nil : author,
            manufacturer: item.manufacturer,
            originalPublishDate: originalPublishDate,
            publisher: publisher.isEmpty ? nil : publisher,
            isbn: isbn.isEmpty ? nil : isbn,
            price: price,
            purchaseDate: purchaseDate,
            synopsis: synopsis.isEmpty ? nil : synopsis,
            customImageData: imageData,
            imageSource: imageData != nil ? .custom : item.imageSource
        )
        
        do {
                try inventoryViewModel.updateItem(updatedItem)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        
        isSaving = false
        }
    }

 