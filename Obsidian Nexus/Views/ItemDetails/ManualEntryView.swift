import SwiftUI

struct ManualEntryView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    
    let type: CollectionType
    
    @State private var title = ""
    @State private var series = ""
    @State private var volume = ""
    @State private var author = ""
    @State private var publisher = ""
    @State private var isbn = ""
    @State private var condition = ItemCondition.good
    @State private var notes = ""
    @State private var publishDate = Date()
    @State private var price: Double = 0
    @State private var purchaseDate = Date()
    @State private var synopsis = ""
    @State private var showingSuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        Form {
            Section("Basic Information") {
                TextField("Title", text: $title)
                TextField("Series (Optional)", text: $series)
                TextField("Volume (Optional)", text: $volume)
                    .keyboardType(.numberPad)
                TextField("Author/Creator", text: $author)
            }
            
            Section("Publishing Details") {
                TextField("Publisher", text: $publisher)
                TextField("ISBN", text: $isbn)
                DatePicker("Publish Date", selection: $publishDate, displayedComponents: .date)
            }
            
            Section("Item Details") {
                Picker("Condition", selection: $condition) {
                    ForEach(ItemCondition.allCases) { condition in
                        Text(condition.rawValue.capitalized)
                            .tag(condition)
                    }
                }
                
                TextField("Notes", text: $notes)
                    .textFieldStyle(.roundedBorder)
            }
            
            Section("Purchase Information") {
                TextField("Price", value: $price, format: .currency(code: "USD"))
                    .keyboardType(.decimalPad)
                DatePicker("Purchase Date", selection: $purchaseDate, displayedComponents: .date)
            }
            
            Section("Additional Details") {
                TextField("Synopsis", text: $synopsis, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .navigationTitle("Manual Entry")
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
                .disabled(title.isEmpty)
            }
        }
        .overlay {
            if showingSuccess {
                VStack {
                    Spacer()
                    Text("Item added to collection!")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(10)
                        .padding()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
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
        let newItem = InventoryItem(
            title: title,
            type: type,
            series: series.isEmpty ? nil : series,
            volume: Int(volume),
            condition: condition,
            notes: notes.isEmpty ? nil : notes,
            author: author.isEmpty ? nil : author,
            originalPublishDate: publishDate,
            publisher: publisher.isEmpty ? nil : publisher,
            isbn: isbn.isEmpty ? nil : isbn,
            price: Decimal(price),
            purchaseDate: purchaseDate,
            synopsis: synopsis.isEmpty ? nil : synopsis
        )
        
        do {
            try inventoryViewModel.addItem(newItem)
            withAnimation {
                showingSuccess = true
            }
            // Dismiss after showing success message
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
} 