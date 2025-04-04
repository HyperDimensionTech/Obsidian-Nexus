import SwiftUI

struct ManualEntryView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var userPreferences: UserPreferences
    
    @State private var title = ""
    @State private var type: CollectionType
    @State private var series = ""
    @State private var volume = ""
    @State private var condition: ItemCondition = .good
    @State private var notes = ""
    @State private var author = ""
    @State private var publisher = ""
    @State private var isbn = ""
    @State private var priceAmount = ""
    @State private var selectedCurrency: Price.Currency
    @State private var purchaseDate = Date()
    @State private var publishDate: Date?
    @State private var showingDatePicker = false
    @State private var synopsis = ""
    @State private var imageData: Data?
    @State private var showingImagePicker = false
    @State private var imageSource: InventoryItem.ImageSource = .none
    @State private var showingSuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingScanner = false
    @State private var isLoading = false
    @State private var locationId: UUID?
    @StateObject private var googleBooksService = GoogleBooksService()
    
    init(type: CollectionType = .books, locationId: UUID? = nil) {
        // Ensure we only use literature types for now
        let initialType = type.isLiterature ? type : .books
        _type = State(initialValue: initialType)
        // Will be initialized with userPreferences in onAppear
        _selectedCurrency = State(initialValue: .usd)
        // Store the preselected location ID
        _locationId = State(initialValue: locationId)
    }
    
    var body: some View {
        Form {
            // Image Section first
            Section("Image") {
                ItemImagePicker(imageData: $imageData)
                    .onChange(of: imageData) { _, newValue in
                        imageSource = newValue != nil ? .custom : .none
                    }
            }
            
            // Basic Information
            Section("Basic Information") {
                TextField("Title", text: $title)
                
                Picker("Type", selection: $type) {
                    ForEach(CollectionType.literatureTypes, id: \.self) { type in
                        Text(type.name).tag(type)
                    }
                }
                
                if type.isLiterature {
                    TextField("Author", text: $author)
                    TextField("Publisher", text: $publisher)
                    HStack {
                        TextField("ISBN", text: $isbn)
                        if type.isLiterature {
                            Button(action: {
                                showingScanner = true
                            }) {
                                Image(systemName: "barcode.viewfinder")
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Scan barcode")
                        }
                    }
                }
                
                TextField("Series", text: $series)
                
                if type.isLiterature {
                    TextField("Volume Number", text: $volume)
                        .keyboardType(.numberPad)
                }
                
                Picker("Condition", selection: $condition) {
                    ForEach(ItemCondition.allCases, id: \.self) { condition in
                        Text(condition.rawValue.capitalized).tag(condition)
                    }
                }
                
                Button(action: {
                    showingDatePicker.toggle()
                }) {
                    HStack {
                        Text("Original Publish Date")
                        Spacer()
                        Text(publishDate?.formatted(date: .abbreviated, time: .omitted) ?? "Not Set")
                            .foregroundColor(.secondary)
                    }
                }
                
                if showingDatePicker {
                    DatePicker("Select Date", selection: Binding(
                        get: { publishDate ?? Date() },
                        set: { publishDate = $0 }
                    ), displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    
                    Button("Clear Date") {
                        publishDate = nil
                    }
                }
            }
            
            Section("Purchase Information") {
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
            
            if isLoading {
                ProgressView("Fetching book details...")
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground)))
                    .shadow(radius: 10)
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            // Set the default currency from user preferences when the view appears
            selectedCurrency = userPreferences.defaultCurrency
        }
        .sheet(isPresented: $showingScanner) {
            BarcodeScannerView { code in
                handleScannedBarcode(code)
            }
        }
    }
    
    private func handleScannedBarcode(_ code: String) {
        // Set ISBN immediately
        isbn = code
        
        // If ISBN format, try to fetch book details
        if code.count == 10 || code.count == 13 {
            isLoading = true
            googleBooksService.fetchBooks(query: "isbn:" + code) { result in
                isLoading = false
                switch result {
                case .success(let books):
                    if let book = books.first {
                        // Pre-fill all available fields
                        title = book.volumeInfo.title
                        author = book.volumeInfo.authors?.first ?? ""
                        publisher = book.volumeInfo.publisher ?? ""
                        synopsis = book.volumeInfo.description ?? ""
                        
                        // Extract series and volume if available
                        let (extractedSeries, extractedVolume) = extractSeriesInfo(from: book.volumeInfo.title)
                        series = extractedSeries ?? ""
                        if let vol = extractedVolume {
                            volume = String(vol)
                        }
                        
                        // Set publish date if available
                        if let dateString = book.volumeInfo.publishedDate {
                            publishDate = parseDate(dateString)
                        }
                        
                        // Set image if available
                        if let thumbnailURL = book.volumeInfo.imageLinks?.thumbnail {
                            loadImage(from: thumbnailURL)
                        }
                    } else {
                        showError("No book found with this ISBN")
                    }
                case .failure(let error):
                    showError("Failed to fetch book: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func loadImage(from urlString: String) {
        var secureUrlString = urlString
        if urlString.hasPrefix("http://") {
            secureUrlString = "https://" + urlString.dropFirst(7)
        }
        
        guard let url = URL(string: secureUrlString) else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let data = data, error == nil {
                DispatchQueue.main.async {
                    self.imageData = data
                    self.imageSource = .googleBooks
                }
            }
        }.resume()
    }
    
    private func extractSeriesInfo(from title: String) -> (String?, Int?) {
        // Simple regex to extract series and volume
        // Example: "One Piece, Vol. 93" -> ("One Piece", 93)
        
        let patterns = [
            // Common manga format: "Series Name, Vol. ##"
            #"^(.*),\s*(?:Vol\.|Volume)\s*(\d+)"#,
            
            // Alternate format: "Series Name ##"
            #"^(.*)\s+#(\d+)"#,
            
            // Series with parentheses: "Series Name (Book ##)"
            #"^(.*)\s+\((?:Book|Volume)\s*(\d+)\)"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(title.startIndex..<title.endIndex, in: title)
                if let match = regex.firstMatch(in: title, options: [], range: range) {
                    let seriesRange = Range(match.range(at: 1), in: title)
                    let volumeRange = Range(match.range(at: 2), in: title)
                    
                    if let seriesRange = seriesRange {
                        let series = String(title[seriesRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        if let volumeRange = volumeRange, 
                           let volume = Int(String(title[volumeRange])) {
                            return (series, volume)
                        }
                        return (series, nil)
                    }
                }
            }
        }
        
        return (nil, nil)
    }
    
    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        
        let formatters = [
            "yyyy-MM-dd",
            "yyyy-MM",
            "yyyy"
        ].map { format -> DateFormatter in
            let formatter = DateFormatter()
            formatter.dateFormat = format
            return formatter
        }
        
        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        return nil
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
    
    private func saveItem() {
        let price: Price?
        if let amount = Decimal(string: priceAmount), Price.isValid(amount) {
            price = Price(amount: amount, currency: selectedCurrency)
        } else {
            price = nil
        }
        
        let newItem = InventoryItem(
            title: title,
            type: type,
            series: series.isEmpty ? nil : series,
            volume: Int(volume),
            condition: condition,
            locationId: locationId,
            notes: notes.isEmpty ? nil : notes,
            author: author.isEmpty ? nil : author,
            originalPublishDate: publishDate,
            publisher: publisher.isEmpty ? nil : publisher,
            isbn: isbn.isEmpty ? nil : isbn,
            price: price,
            purchaseDate: purchaseDate,
            synopsis: synopsis.isEmpty ? nil : synopsis,
            customImageData: imageData,
            imageSource: imageSource
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