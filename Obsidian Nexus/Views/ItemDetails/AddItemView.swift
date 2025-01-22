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
            
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search by title or ISBN", text: $searchQuery)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        performSearch()
                    }
                
                if isSearching {
                    ProgressView()
                        .padding(.horizontal)
                }
            }
            .padding(.horizontal)
            
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
                                addBookToInventory(selectedBook)
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
    
    private func addBookToInventory(_ book: GoogleBook) {
        // Extract ISBN if available
        let isbn = book.volumeInfo.industryIdentifiers?
            .first(where: { $0.type == "ISBN_13" })?.identifier
        
        // Process thumbnail URL
        var thumbnailURL: URL?
        if let thumbnail = book.volumeInfo.imageLinks?.thumbnail {
            thumbnailURL = URL(string: thumbnail.replacingOccurrences(of: "http://", with: "https://"))
        }
        
        // Create new inventory item
        let newItem = InventoryItem(
            title: book.volumeInfo.title,
            type: detectItemType(book),
            series: extractSeriesInfo(from: book.volumeInfo.title).series,
            volume: extractSeriesInfo(from: book.volumeInfo.title).volume,
            condition: .good,
            locationId: nil,
            notes: book.volumeInfo.description,
            dateAdded: Date(),
            barcode: nil,
            thumbnailURL: thumbnailURL,
            author: book.volumeInfo.authors?.first,
            manufacturer: nil,
            originalPublishDate: parseDate(book.volumeInfo.publishedDate),
            publisher: book.volumeInfo.publisher,
            isbn: isbn,
            price: nil,
            purchaseDate: nil
        )
        
        do {
            try inventoryViewModel.addItem(newItem)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func detectItemType(_ book: GoogleBook) -> CollectionType {
        let title = book.volumeInfo.title.lowercased()
        let publisher = book.volumeInfo.publisher?.lowercased() ?? ""
        let description = book.volumeInfo.description?.lowercased() ?? ""
        
        // Check manga first (since it's most specific)
        if PublisherType.manga.publishers.contains(where: { publisher.contains($0) }) ||
           PublisherType.manga.searchKeywords.contains(where: { title.contains($0) }) ||
           description.contains("manga") {
            return .manga
        }
        
        // Then check comics
        if PublisherType.comics.publishers.contains(where: { publisher.contains($0) }) ||
           PublisherType.comics.searchKeywords.contains(where: { title.contains($0) }) ||
           description.contains("comic") {
            return .comics
        }
        
        // Default to books
        return .books
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
}

#Preview {
    let locationManager = LocationManager()
    let inventoryViewModel = InventoryViewModel(locationManager: locationManager)
    
    return NavigationView {
        AddItemView()
            .environmentObject(inventoryViewModel)
            .environmentObject(locationManager)
    }
} 