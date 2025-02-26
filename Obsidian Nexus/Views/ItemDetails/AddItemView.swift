import SwiftUI

struct AddItemView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @StateObject private var googleBooksService = GoogleBooksService()
    
    // Move mangaPublishers here as a static property
    private static let mangaPublishers = [
        "viz",
        "kodansha",
        "shogakukan", 
        "shueisha",
        "square enix",
        "seven seas",
        "yen press",
        "dark horse manga",
        "vertical comics"
    ]
    
    @State private var selectedType: CollectionType = .books
    @State private var searchQuery = ""
    @State private var searchResults: [GoogleBook] = []
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isSearching = false
    @State private var showingManualEntry = false
    @State private var showingScanner = false
    @State private var continuousEntryMode = false
    @State private var addedCount = 0
    @State private var failedScans: [(code: String, reason: String)] = []
    @State private var showingResults = false
    @State private var lastAddedTitle: String?
    @State private var showingAddConfirmation = false
    @FocusState private var isSearchFieldFocused: Bool
    @State private var successfulScans: [(title: String, isbn: String?)] = []
    
    var sortedResults: [GoogleBook] {
        searchResults.sorted { book1, book2 in
            if let vol1 = googleBooksService.extractVolumeNumber(from: book1.volumeInfo.title),
               let vol2 = googleBooksService.extractVolumeNumber(from: book2.volumeInfo.title) {
                return vol1 < vol2
            }
            return book1.volumeInfo.title < book2.volumeInfo.title
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Category Picker
            Picker("Category", selection: $selectedType) {
                Text("Literature").tag(CollectionType.books)
                // Future categories - commented out until implemented
                // Text("Electronics").tag(CollectionType.electronics)
                // Text("Collectibles").tag(CollectionType.collectibles)
                // Text("Tools").tag(CollectionType.tools)
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Search Bar with Continuous Mode Toggle
            HStack {
                TextField("Search by title, author, or ISBN...", text: $searchQuery)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .focused($isSearchFieldFocused)
                    .onSubmit {
                        if continuousEntryMode {
                            handleContinuousSearch()
                        } else {
                            performSearch()
                        }
                    }
                
                if searchQuery.isEmpty {
                    Button(action: { showingScanner = true }) {
                        Image(systemName: "barcode.viewfinder")
                            .font(.system(size: 20))
                    }
                } else {
                    Button(action: { searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal)
            
            // Continuous Mode Toggle
            Toggle("Continuous Entry Mode", isOn: Binding(
                get: { continuousEntryMode },
                set: { newValue in 
                    continuousEntryMode = newValue
                    if newValue {
                        // Focus the search field when continuous mode is enabled
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isSearchFieldFocused = true
                        }
                    }
                }
            ))
            .toggleStyle(.button)
            .tint(.blue)
            .padding(.horizontal)
            
            if continuousEntryMode {
                HStack {
                    Text("Added: \(addedCount)")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button("Review Results") {
                        showingResults = true
                    }
                    .disabled(addedCount == 0)
                }
                .padding(.horizontal)
                
                if let title = lastAddedTitle {
                    Text("Last added: \(title)")
                        .foregroundColor(.green)
                        .padding(.horizontal)
                        .transition(.opacity)
                }
            }
            
            // Manual Entry Button
            Button {
                showingManualEntry = true
            } label: {
                HStack {
                    Image(systemName: "square.and.pencil")
                    Text("Manual Entry")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding()
            
            Divider()
            
            // Results
            if searchResults.isEmpty && !isSearching {
                ContentUnavailableView {
                    Label("No Results", systemImage: "magnifyingglass")
                } description: {
                    Text("Search for items to add to your collection")
                }
            } else {
                ScrollView {
                    LazyVStack {
                        ForEach(sortedResults, id: \.id) { book in
                            BookSearchResultView(book: book) { selectedBook in
                                addToCollection(selectedBook)
                            }
                            .padding(.horizontal)
                            Divider()
                        }
                    }
                }
            }
        }
        .navigationTitle("Add Item")
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showingManualEntry) {
            NavigationView {
                ManualEntryView(type: selectedType)
            }
        }
        .sheet(isPresented: $showingScanner) {
            BarcodeScannerView { code in
                searchQuery = "isbn:" + code  // Add the isbn: prefix
                showingScanner = false
                performSearch()
            }
        }
        .sheet(isPresented: $showingResults) {
            ScanResultsView(
                scannedCount: addedCount,
                successfulScans: successfulScans,
                failedScans: failedScans
            )
        }
    }
    
    private func performSearch() {
        guard !searchQuery.isEmpty else { return }
        isSearching = true
        
        // Simple, direct search
        googleBooksService.fetchBooks(query: searchQuery) { result in
            isSearching = false
            switch result {
            case .success(let books):
                print("Found \(books.count) results") // Debug print
                searchResults = books
            case .failure(let error):
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    private func addToCollection(_ book: GoogleBook) {
        // Detect the correct type
        let detectedType = detectItemType(book)
        
        // Process the thumbnail URL to ensure it uses HTTPS
        let thumbnailURL = book.volumeInfo.imageLinks?.thumbnail.flatMap { urlString -> URL? in
            var secureUrlString = urlString
            if urlString.hasPrefix("http://") {
                secureUrlString = "https://" + urlString.dropFirst(7)
            }
            return URL(string: secureUrlString)
        }
        
        let newItem = InventoryItem(
            title: book.volumeInfo.title,
            type: detectedType,
            series: extractSeriesInfo(from: book.volumeInfo.title).0,
            volume: extractSeriesInfo(from: book.volumeInfo.title).1,
            condition: .good,
            notes: nil,
            dateAdded: Date(),
            barcode: nil,
            thumbnailURL: thumbnailURL,  // Use the processed HTTPS URL
            author: book.volumeInfo.authors?.first,
            manufacturer: nil,
            originalPublishDate: parseDate(book.volumeInfo.publishedDate),
            publisher: book.volumeInfo.publisher,
            isbn: book.volumeInfo.industryIdentifiers?.first?.identifier,
            price: nil,
            purchaseDate: nil,
            synopsis: book.volumeInfo.description
        )
        
        do {
            try inventoryViewModel.addItem(newItem)
            withAnimation {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func detectItemType(_ book: GoogleBook) -> CollectionType {
        let title = book.volumeInfo.title.lowercased()
        let publisher = book.volumeInfo.publisher?.lowercased() ?? ""
        let description = book.volumeInfo.description?.lowercased() ?? ""
        
        // Check for manga publishers and keywords
        let mangaPublishers = ["viz media", "kodansha", "yen press", "dark horse manga", "seven seas"]
        let mangaKeywords = ["manga", "volume", "vol."]
        
        if mangaPublishers.contains(where: { publisher.contains($0) }) ||
           mangaKeywords.contains(where: { title.contains($0) }) ||
           description.contains("manga") {
            return .manga
        }
        
        // Check for comics
        let comicPublishers = ["marvel", "dc comics", "image comics", "dark horse comics"]
        let comicKeywords = ["comic", "graphic novel"]
        
        if comicPublishers.contains(where: { publisher.contains($0) }) ||
           comicKeywords.contains(where: { title.contains($0) }) ||
           description.contains("comic") {
            return .comics
        }
        
        // Default to selected type if no specific type is detected
        return selectedType
    }
    
    private func extractSeriesInfo(from title: String) -> (series: String?, volume: Int?) {
        let lowercasedTitle = title.lowercased()
        
        // Common volume indicators with more patterns
        let volumePatterns = [
            "vol\\.?\\s*(\\d+)",
            "volume\\s*(\\d+)",
            "v(\\d+)",
            "#(\\d+)",
            "\\s(\\d+)$",  // Number at end
            "\\s(\\d+)\\s" // Number surrounded by spaces
        ]
        
        // First, try to extract volume number
        var volumeNumber: Int?
        for pattern in volumePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: title, options: [], range: NSRange(title.startIndex..., in: title)),
               let range = Range(match.range(at: 1), in: title) {
                volumeNumber = Int(title[range])
                    break
            }
        }
        
        // Then extract series name
        var seriesName: String?
        
        // Try different volume separators
        let separators = [" vol", " volume", " v", "#"]
        for separator in separators {
            if let range = lowercasedTitle.range(of: separator, options: .caseInsensitive) {
                seriesName = String(title[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                break
            }
        }
        
        // If no series name found, try splitting by comma or hyphen
        if seriesName == nil {
            if let commaRange = title.range(of: ",") {
                seriesName = String(title[..<commaRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            } else if let hyphenRange = title.range(of: " - ") {
                seriesName = String(title[..<hyphenRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            }
        }
        
        // Special handling for common manga series patterns
        let knownSeries = [
            "one piece": "One Piece",
            "naruto": "Naruto",
            "dragon ball": "Dragon Ball",
            "bleach": "Bleach"
        ]
        
        // Check if the title starts with any known series
        for (key, value) in knownSeries {
            if lowercasedTitle.starts(with: key) {
                seriesName = value
                break
            }
        }
        
        return (seriesName, volumeNumber)
    }
    
    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        // Try full date format (2023-04-15)
        dateFormatter.dateFormat = "yyyy-MM-dd"
        if let date = dateFormatter.date(from: dateString) {
            return date
        }
        
        // Try year-month format (2023-04)
        dateFormatter.dateFormat = "yyyy-MM"
        if let date = dateFormatter.date(from: dateString) {
            return date
        }
        
        // Try year only format (2023)
        dateFormatter.dateFormat = "yyyy"
        if let date = dateFormatter.date(from: dateString) {
            return date
        }
        
        return nil
    }
    
    private func handleContinuousSearch() {
        guard !searchQuery.isEmpty else { return }
        
        // Check if it's an ISBN
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        let isbnQuery = query.replacingOccurrences(of: "[^0-9X]", with: "", options: .regularExpression)
        
        if isbnQuery.count == 10 || isbnQuery.count == 13 {
            isSearching = true
            
            // Search for the ISBN
            googleBooksService.fetchBooks(query: "isbn:\(isbnQuery)") { result in
                DispatchQueue.main.async {
                    self.isSearching = false
                    
                    switch result {
                    case .success(let books):
                        if let book = books.first {
                            do {
                                let newItem = self.inventoryViewModel.createItemFromGoogleBook(book)
                                try self.inventoryViewModel.addItem(newItem)
                                self.addedCount += 1
                                self.lastAddedTitle = book.volumeInfo.title
                                self.successfulScans.append((
                                    title: book.volumeInfo.title,
                                    isbn: book.volumeInfo.industryIdentifiers?.first?.identifier
                                ))
                                
                                // Clear search field for next entry
                                self.searchQuery = ""
                                
                                // Show confirmation briefly
                                withAnimation {
                                    self.showingAddConfirmation = true
                                }
                                
                                // Clear confirmation after delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    withAnimation {
                                        self.showingAddConfirmation = false
                                        self.lastAddedTitle = nil
                                    }
                                }
                                
                                // Re-focus the search field for the next scan
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    self.isSearchFieldFocused = true
                                }
                            } catch {
                                self.failedScans.append((isbnQuery, error.localizedDescription))
                                self.searchQuery = ""
                            }
                        } else {
                            self.failedScans.append((isbnQuery, "No book found"))
                            self.searchQuery = ""
                        }
                    case .failure(let error):
                        self.failedScans.append((isbnQuery, error.localizedDescription))
                        self.searchQuery = ""
                    }
                }
            }
        } else {
            // Not an ISBN, perform regular search
            performSearch()
        }
    }
}

#Preview {
    let locationManager = LocationManager()
    let inventoryViewModel = InventoryViewModel(
        storage: .shared,
        locationManager: locationManager
    )
    
    return NavigationView {
        AddItemView()
            .environmentObject(inventoryViewModel)
            .environmentObject(locationManager)
    }
} 