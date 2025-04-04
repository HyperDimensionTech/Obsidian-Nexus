import SwiftUI
import CoreHaptics

// MARK: - Sort Options
enum BookSortOption: String, CaseIterable, Identifiable {
    case relevance = "Relevance"
    case titleAsc = "Title (A-Z)"
    case titleDesc = "Title (Z-A)"
    case authorAsc = "Author (A-Z)"
    case authorDesc = "Author (Z-A)"
    case publisherAsc = "Publisher (A-Z)"
    case publisherDesc = "Publisher (Z-A)"
    case newestFirst = "Newest First"
    case oldestFirst = "Oldest First"
    
    var id: String { self.rawValue }
    
    func sortBooks(_ books: [GoogleBook]) -> [GoogleBook] {
        switch self {
        case .relevance:
            // Default order from API
            return books
        case .titleAsc:
            return books.sorted { $0.volumeInfo.title.localizedCaseInsensitiveCompare($1.volumeInfo.title) == .orderedAscending }
        case .titleDesc:
            return books.sorted { $0.volumeInfo.title.localizedCaseInsensitiveCompare($1.volumeInfo.title) == .orderedDescending }
        case .authorAsc:
            return books.sorted {
                let author1 = $0.volumeInfo.authors?.first ?? ""
                let author2 = $1.volumeInfo.authors?.first ?? ""
                return author1.localizedCaseInsensitiveCompare(author2) == .orderedAscending
            }
        case .authorDesc:
            return books.sorted {
                let author1 = $0.volumeInfo.authors?.first ?? ""
                let author2 = $1.volumeInfo.authors?.first ?? ""
                return author1.localizedCaseInsensitiveCompare(author2) == .orderedDescending
            }
        case .publisherAsc:
            return books.sorted {
                let publisher1 = $0.volumeInfo.publisher ?? ""
                let publisher2 = $1.volumeInfo.publisher ?? ""
                return publisher1.localizedCaseInsensitiveCompare(publisher2) == .orderedAscending
            }
        case .publisherDesc:
            return books.sorted {
                let publisher1 = $0.volumeInfo.publisher ?? ""
                let publisher2 = $1.volumeInfo.publisher ?? ""
                return publisher1.localizedCaseInsensitiveCompare(publisher2) == .orderedDescending
            }
        case .newestFirst:
            return books.sorted {
                let date1 = AddItemView.parseDate($0.volumeInfo.publishedDate) ?? Date.distantPast
                let date2 = AddItemView.parseDate($1.volumeInfo.publishedDate) ?? Date.distantPast
                return date1 > date2
            }
        case .oldestFirst:
            return books.sorted {
                let date1 = AddItemView.parseDate($0.volumeInfo.publishedDate) ?? Date.distantPast
                let date2 = AddItemView.parseDate($1.volumeInfo.publishedDate) ?? Date.distantPast
                return date1 < date2
            }
        }
    }
}

struct AddItemView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @StateObject private var googleBooksService = GoogleBooksService()
    @StateObject private var isbnMappingService = ISBNMappingService(storage: .shared)
    @EnvironmentObject private var scanManager: ScanResultManager
    @EnvironmentObject private var locationManager: LocationManager
    
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
    @State private var showingResults = false
    @FocusState private var isSearchFieldFocused: Bool
    @State private var addedItemScale: CGFloat = 1.0
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var hapticEngine: CHHapticEngine?
    @State private var selectedSortOption: BookSortOption = .relevance
    @State private var showingSortOptions = false
    @State private var showingISBNLinking = false
    @State private var currentFailedISBN = ""
    @State private var showingLinkPrompt = false
    @State private var isProcessingBook = false
    @State private var preselectedLocationId: UUID?
    
    // Add initializer that accepts a locationId
    init(locationId: UUID? = nil) {
        _preselectedLocationId = State(initialValue: locationId)
    }
    
    var sortedResults: [GoogleBook] {
        // First apply the existing volume sorting logic
        let volumeSorted = searchResults.sorted { (book1, book2) -> Bool in
            // Extract volume numbers if present
            let vol1 = googleBooksService.extractVolumeNumber(from: book1.volumeInfo.title) ?? 0
            let vol2 = googleBooksService.extractVolumeNumber(from: book2.volumeInfo.title) ?? 0
            
            // If both have volume numbers, sort by volume
            if vol1 > 0 && vol2 > 0 {
                return vol1 < vol2
            }
            
            // Otherwise sort by title
            return book1.volumeInfo.title < book2.volumeInfo.title
        }
        
        // Then apply the selected sort option
        return selectedSortOption.sortBooks(volumeSorted)
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 16) {
                    // Title is now provided by navigation title
                    searchBarView
                    actionButtonsView
                    continuousModeToggleView
                    
                    // Continuous Mode Status (only shown when active)
                    if continuousEntryMode {
                        continuousModeStatusView
                    }
                    
                    // Add sort options UI
                    if !searchResults.isEmpty {
                        sortOptionsView
                    }
                    
                    resultsView
                }
                // Add extra padding at bottom to make room for the fixed manual entry button
                .padding(.bottom, 80)
            }
            
            // Fixed Manual Entry button at bottom of screen
            VStack {
                manualEntryButton
            }
            .padding(.bottom, 10) // Position above tab bar
            .background(Color(.systemBackground))
            
            .overlay {
                // Toast notification
                if showToast {
                    toastView
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Item added")
                        .accessibilityValue(toastMessage)
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("ISBN Not Found", isPresented: $showingLinkPrompt) {
            Button("Link Now", role: .none) {
                showingISBNLinking = true
                showingLinkPrompt = false
            }
            Button("Skip", role: .cancel) {
                // Just continue scanning
                refocusSearchField()
            }
        } message: {
            Text("Would you like to link this ISBN to a book in Google Books?")
        }
        .accessibilityAction(.escape) {
            // Provide an escape action for accessibility users
            dismiss()
        }
        .sheet(isPresented: $showingManualEntry) {
            NavigationView {
                ManualEntryView(type: selectedType, locationId: preselectedLocationId)
            }
            .accessibilityLabel("Manual Entry")
            .accessibilityHint("Enter item details manually")
        }
        .sheet(isPresented: $showingScanner) {
            BarcodeScannerView { code in
                searchQuery = "isbn:" + code  // Add the isbn: prefix
                showingScanner = false
                // Always perform a regular search instead of direct continuous mode handling
                performSearch()
            }
            .accessibilityLabel("Barcode Scanner")
            .accessibilityHint("Point camera at a barcode to scan")
        }
        .sheet(isPresented: $showingResults) {
            ScanResultsView(
                scanManager: scanManager,
                onContinue: {
                    showingResults = false
                    // Optionally re-focus the search field
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.isSearchFieldFocused = true
                    }
                },
                onFinish: {
                    showingResults = false
                }
            )
        }
        .sheet(isPresented: $showingISBNLinking) {
            ISBNLinkingView(
                isbn: currentFailedISBN,
                onBookSelected: { book in
                    // Process the selected book
                    self.processFoundBook(book, originalIsbn: currentFailedISBN)
                    
                    // Announce success for VoiceOver users
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: "ISBN \(currentFailedISBN) linked to \(book.volumeInfo.title)"
                    )
                }
            )
            .onDisappear {
                // Re-focus the search field when the linking view is dismissed
                if continuousEntryMode {
                    refocusSearchField()
                }
            }
        }
        .confirmationDialog("Sort Options", isPresented: $showingSortOptions) {
            ForEach(BookSortOption.allCases) { option in
                Button(option.rawValue) {
                    selectedSortOption = option
                }
                .accessibilityHint("Sort results by \(option.rawValue)")
            }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear(perform: prepareHaptics)
        .onDisappear(perform: cleanupResources)
    }
    
    // MARK: - Lifecycle Methods
    
    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
            
            // Set up haptic engine reset handler
            hapticEngine?.resetHandler = {
                // The engine stopped; attempt to restart it
                do {
                    try self.hapticEngine?.start()
                } catch {
                    print("Failed to restart the haptic engine: \(error.localizedDescription)")
                }
            }
            
            // Set up haptic engine stopped handler
            hapticEngine?.stoppedHandler = { reason in
                print("Haptic engine stopped: \(reason.rawValue)")
            }
        } catch {
            print("There was an error creating the haptic engine: \(error.localizedDescription)")
        }
    }
    
    private func cleanupResources() {
        // Stop the haptic engine to free resources
        hapticEngine?.stop()
        
        // Clear any large data sets that aren't needed
        if !continuousEntryMode {
            searchResults = []
        }
    }
    
    // MARK: - Extracted Subviews
    
    private var searchBarView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            
            TextField("Search by title, author, or ISBN...", text: $searchQuery)
                .submitLabel(.search)
                .focused($isSearchFieldFocused)
                .onSubmit {
                    if !searchQuery.isEmpty {
                        // Always just perform search, don't handle continuous search separately here
                        performSearch()
                    }
                }
            
            if !searchQuery.isEmpty {
                Button(action: {
                    searchQuery = ""
                    searchResults = []
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .padding(.trailing, 4)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .accessibilityLabel("Search field")
        .accessibilityHint("Enter a book title, author name, or ISBN to search")
    }
    
    private var actionButtonsView: some View {
        HStack(spacing: 12) {
            Button(action: performSearch) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16))
                    Text("Search")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .accessibilityLabel("Search")
            .accessibilityHint("Search for books with the entered query")
            
            Button(action: { showingScanner = true }) {
                HStack {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 16))
                    Text("Scan")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .accessibilityLabel("Scan barcode")
            .accessibilityHint("Open camera to scan a book barcode")
        }
        .padding(.horizontal)
    }
    
    private var continuousModeToggleView: some View {
        VStack {
            Toggle(isOn: $continuousEntryMode) {
                HStack {
                    Image(systemName: "repeat")
                        .font(.system(size: 16))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Continuous Add Mode")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Add selected items directly to collection")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .toggleStyle(.switch)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
        }
        .padding(.horizontal)
        .onChange(of: continuousEntryMode) { _, newValue in
            if newValue {
                // Focus the search field when continuous mode is enabled
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isSearchFieldFocused = true
                }
                
                // Announce mode change for VoiceOver users
                UIAccessibility.post(notification: .announcement, argument: "Continuous add mode enabled")
            } else if scanManager.totalScannedCount > 0 {
                // Announce summary when disabling with items added
                UIAccessibility.post(notification: .announcement, argument: "Continuous mode disabled. Added \(scanManager.totalScannedCount) items.")
            }
        }
        .accessibilityLabel("Continuous Add Mode")
        .accessibilityHint("When enabled, automatically adds items to your collection without stopping")
        .accessibilityValue(continuousEntryMode ? "Enabled" : "Disabled")
    }
    
    private var continuousModeStatusView: some View {
        VStack {
            HStack {
                VStack(alignment: .leading) {
                    Text("Added: \(scanManager.totalScannedCount)")
                        .font(.headline)
                    
                    if let title = scanManager.lastAddedTitle {
                        Text("Last added: \(title)")
                            .font(.caption)
                            .foregroundColor(.green)
                            .lineLimit(1)
                            .scaleEffect(addedItemScale)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: addedItemScale)
                    }
                }
                
                Spacer()
                
                Button(action: { showingResults = true }) {
                    Text("Review")
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(scanManager.totalScannedCount == 0)
                .opacity(scanManager.totalScannedCount == 0 ? 0.5 : 1)
                .accessibilityLabel("Review added items")
                .accessibilityHint("View the list of successfully added items")
                .accessibilityAddTraits(scanManager.totalScannedCount == 0 ? [] : [.isButton])
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
        }
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Continuous mode status")
        .accessibilityValue("\(scanManager.totalScannedCount) items added\(scanManager.lastAddedTitle != nil ? ", last added: \(scanManager.lastAddedTitle!)" : "")")
    }
    
    private var sortOptionsView: some View {
        HStack {
            Text("\(searchResults.count) results")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: {
                showingSortOptions = true
            }) {
                HStack {
                    Text("Sort: \(selectedSortOption.rawValue)")
                        .font(.subheadline)
                    Image(systemName: "arrow.up.arrow.down")
                }
                .foregroundColor(.accentColor)
            }
            .accessibilityLabel("Sort options")
            .accessibilityHint("Change how search results are sorted")
            .accessibilityValue("Currently sorted by \(selectedSortOption.rawValue)")
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var resultsView: some View {
        Group {
            if isSearching {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
                    .frame(maxHeight: .infinity, alignment: .center)
                    .accessibilityLabel("Searching")
                    .accessibilityHint("Please wait while we search for results")
            } else if searchResults.isEmpty {
                emptyStateView
            } else {
                searchResultsListView
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 24) {
                Image(systemName: "magnifyingglass.circle")
                    .font(.system(size: 70))
                    .foregroundStyle(.tertiary)
                    .symbolRenderingMode(.hierarchical)
                    .accessibilityHidden(true)
                
                VStack(spacing: 8) {
                    Text("Add to Your Collection")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Search, scan, or manually add items")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 250)
                }
            }
            .padding(.bottom, 40)
            
            Spacer()
        }
        .frame(maxHeight: 500)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No search results")
        .accessibilityHint("Enter a search term or use manual entry to add an item")
    }
    
    private var searchResultsListView: some View {
        VStack {
            // Results list
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(sortedResults, id: \.id) { book in
                        BookResultCard(book: book, onSelect: addToCollection, continuousMode: $continuousEntryMode)
                            .padding(.horizontal)
                    }
                }
                .padding(.top, 8)
                .accessibilityLabel("Search results")
            }
        }
    }
    
    private var manualEntryButton: some View {
        Button {
            showingManualEntry = true
        } label: {
            HStack {
                Image(systemName: "square.and.pencil")
                Text("Manual Entry")
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding(.horizontal)
        .padding(.bottom)
        .accessibilityLabel("Manual Entry")
        .accessibilityHint("Add an item by manually entering its details")
    }
    
    private var toastView: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Added to Collection")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(toastMessage)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.green)
                    .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 2)
                    .accessibilityHidden(true)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    
    // MARK: - Haptic Feedback Methods
    
    private func triggerSuccessHaptic() {
        if CHHapticEngine.capabilitiesForHardware().supportsHaptics {
            triggerAdvancedHaptic()
        } else {
            triggerBasicHaptic()
        }
    }
    
    private func triggerAdvancedHaptic() {
        guard let engine = hapticEngine else { return }
        
        // Create a pattern of haptic events
        var events = [CHHapticEvent]()
        
        // Create an intense, sharp tap
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        events.append(event)
        
        // Convert the events into a pattern and play it
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play haptic pattern: \(error.localizedDescription)")
        }
    }
    
    private func triggerBasicHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    // MARK: - UI Helper Methods
    
    private func showSuccessToast(title: String) {
        toastMessage = title
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            showToast = true
        }
        
        // Hide the toast after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                showToast = false
            }
        }
        
        // Announce the addition for VoiceOver users
        UIAccessibility.post(notification: .announcement, argument: "Added \(title) to collection")
    }
    
    // MARK: - Core Functionality Methods
    
    private func performSearch() {
        guard !searchQuery.isEmpty else { return }
        isSearching = true
        
        // Check if it's an ISBN search
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        if query.hasPrefix("isbn:") {
            // Extract the ISBN from the query
            let isbnQuery = query.replacingOccurrences(of: "isbn:", with: "")
                .replacingOccurrences(of: "[^0-9X]", with: "", options: .regularExpression)
            
            if isbnQuery.count == 10 || isbnQuery.count == 13 {
                // It's a valid ISBN, search for it
                performISBNSearch(isbnQuery)
                return
            }
        }
        
        // Regular search
        googleBooksService.fetchBooks(query: searchQuery) { result in
            DispatchQueue.main.async {
                self.isSearching = false
                switch result {
                case .success(let books):
                    print("Found \(books.count) results") // Debug print
                    self.searchResults = books
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                }
            }
        }
    }
    
    private func performISBNSearch(_ isbnQuery: String) {
        // First check user-defined mappings
        if let mapping = isbnMappingService.getMappingForISBN(isbnQuery) {
            // Use the Google Books ID from user mapping
            googleBooksService.fetchBookById(mapping.correctGoogleBooksID) { result in
                DispatchQueue.main.async {
                    self.isSearching = false
                    
                    switch result {
                    case .success(let book):
                        // Show the result
                        self.searchResults = [book]
                    case .failure(_):
                        // If direct fetch fails, try a title search as fallback
                        self.searchByTitle(mapping.title, originalIsbn: isbnQuery)
                    }
                }
            }
            return
        }
        
        // If no mapping found, perform a regular ISBN search
        googleBooksService.fetchBooksByISBN(isbnQuery) { result in
            DispatchQueue.main.async {
                self.isSearching = false
                
                switch result {
                case .success(let books):
                    if !books.isEmpty {
                        self.searchResults = books
                    } else {
                        self.handleNoBookFound(isbnQuery)
                    }
                case .failure(let error):
                    self.errorMessage = "Error searching for ISBN: \(error.localizedDescription)"
                    self.showingError = true
                }
            }
        }
    }
    
    private func addToCollection(_ book: GoogleBook) {
        // Create a new inventory item from the book
        let newItem = createInventoryItem(from: book)
        
        // Set the location ID to the preselected one if available
        var itemWithLocation = newItem
        itemWithLocation.locationId = preselectedLocationId
        
        do {
            try inventoryViewModel.addItem(itemWithLocation)
            
            // Provide feedback
            triggerSuccessHaptic()
            showSuccessToast(title: book.volumeInfo.title)
            
            // Update scan manager
            scanManager.addSuccessfulScan(
                title: book.volumeInfo.title,
                isbn: book.volumeInfo.industryIdentifiers?.first?.identifier
            )
            
            // If not in continuous mode, dismiss the view after adding
            if !continuousEntryMode {
                withAnimation {
                    dismiss()
                }
            } else {
                // If in continuous mode, just keep showing the search results
                // But provide appropriate feedback through the toast notification
                
                // Announce for VoiceOver in continuous mode
                UIAccessibility.post(notification: .announcement, argument: "Added \(book.volumeInfo.title). Continue adding items or tap finish when done.")
                
                // Animate the last added item
                animateLastAddedItem()
            }
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func createInventoryItem(from book: GoogleBook) -> InventoryItem {
        // Detect the correct type
        let detectedType = detectItemType(book)
        
        // Process the thumbnail URL to ensure it uses HTTPS
        let thumbnailURL = processBookThumbnailURL(book.volumeInfo.imageLinks?.thumbnail)
        
        // Extract series and volume information
        let (series, volume) = extractSeriesInfo(from: book.volumeInfo.title)
        
        return InventoryItem(
            title: book.volumeInfo.title,
            type: detectedType,
            series: series,
            volume: volume,
            condition: .good,
            notes: nil,
            dateAdded: Date(),
            barcode: nil,
            thumbnailURL: thumbnailURL,
            author: book.volumeInfo.authors?.first,
            manufacturer: nil,
            originalPublishDate: parseDate(book.volumeInfo.publishedDate),
            publisher: book.volumeInfo.publisher,
            isbn: book.volumeInfo.industryIdentifiers?.first?.identifier,
            price: nil,
            purchaseDate: nil,
            synopsis: book.volumeInfo.description
        )
    }
    
    private func processBookThumbnailURL(_ urlString: String?) -> URL? {
        guard let urlString = urlString else { return nil }
        
        var secureUrlString = urlString
        if urlString.hasPrefix("http://") {
            secureUrlString = "https://" + urlString.dropFirst(7)
        }
        return URL(string: secureUrlString)
    }
    
    // MARK: - Data Processing Methods
    
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
        
        // Extract volume number
        let volumeNumber = extractVolumeNumber(from: title)
        
        // Extract series name
        let seriesName = extractSeriesName(from: title, lowercasedTitle: lowercasedTitle)
        
        return (seriesName, volumeNumber)
    }
    
    private func extractVolumeNumber(from title: String) -> Int? {
        // Common volume indicators with more patterns
        let volumePatterns = [
            "vol\\.?\\s*(\\d+)",
            "volume\\s*(\\d+)",
            "v(\\d+)",
            "#(\\d+)",
            "\\s(\\d+)$",  // Number at end
            "\\s(\\d+)\\s" // Number surrounded by spaces
        ]
        
        // Try to extract volume number using patterns
        for pattern in volumePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: title, options: [], range: NSRange(title.startIndex..., in: title)),
               let range = Range(match.range(at: 1), in: title) {
                return Int(title[range])
            }
        }
        
        return nil
    }
        
    private func extractSeriesName(from title: String, lowercasedTitle: String) -> String? {
        // Try different volume separators
        let separators = [" vol", " volume", " v", "#"]
        for separator in separators {
            if let range = lowercasedTitle.range(of: separator, options: .caseInsensitive) {
                return String(title[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            }
        }
        
        // If no series name found, try splitting by comma or hyphen
            if let commaRange = title.range(of: ",") {
            return String(title[..<commaRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            } else if let hyphenRange = title.range(of: " - ") {
            return String(title[..<hyphenRange.lowerBound]).trimmingCharacters(in: .whitespaces)
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
                return value
            }
        }
        
        return nil
    }
    
    // Add static parseDate method for use in BookSortOption
    static func parseDate(_ dateString: String?) -> Date? {
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
    
    private func parseDate(_ dateString: String?) -> Date? {
        return AddItemView.parseDate(dateString)
    }
    
    // MARK: - Continuous Mode Methods
    
    private func animateLastAddedItem() {
        addedItemScale = 1.2
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.addedItemScale = 1.0
        }
    }
    
    private func refocusSearchField() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isSearchFieldFocused = true
        }
    }
    
    // New method to handle when no book is found for an ISBN
    private func handleNoBookFound(_ isbnQuery: String) {
        // Store the failed ISBN for later use
        currentFailedISBN = isbnQuery
        
        // Add to failed scans
        scanManager.addFailedScan(code: isbnQuery, reason: "No book found")
        
        // Clear search field
        searchQuery = ""
        
        // Show link prompt
        showingLinkPrompt = true
        
        // Announce the failure for VoiceOver users
        UIAccessibility.post(notification: .announcement, argument: "Scan failed: No book found")
    }
    
    // Method to search by title as a fallback
    private func searchByTitle(_ title: String, originalIsbn: String) {
        googleBooksService.fetchBooks(query: title) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let books):
                    if let book = books.first {
                        self.processFoundBook(book, originalIsbn: originalIsbn)
                    } else {
                        self.handleNoBookFound(originalIsbn)
                    }
                case .failure(_):
                    self.handleNoBookFound(originalIsbn)
                }
            }
        }
    }
    
    private func processFoundBook(_ book: GoogleBook, originalIsbn: String) {
        do {
            // Create a new item from the Google Book
            let newItem = inventoryViewModel.createItemFromGoogleBook(book)
            print("Created item: \(newItem.title) with location: \(String(describing: newItem.locationId))")
            
            // Add it to the inventory without location - locations are handled elsewhere
            try inventoryViewModel.addItem(newItem)
            print("Successfully added item to inventory")
            
            // Update scan count and display
            scanManager.addSuccessfulScan(
                title: book.volumeInfo.title,
                isbn: book.volumeInfo.industryIdentifiers?.first?.identifier
            )
            
            // Clear search field for next entry
            searchQuery = ""
            
            // Provide feedback
            triggerSuccessHaptic()
            showSuccessToast(title: book.volumeInfo.title)
            
            // Announce for VoiceOver in continuous mode
            if continuousEntryMode {
                UIAccessibility.post(notification: .announcement, argument: "Added \(book.volumeInfo.title). Ready for next scan.")
            }
            
            // Animate the last added item
            animateLastAddedItem()
            
            // Re-focus the search field for the next scan
            refocusSearchField()
            
        } catch let error as InventoryViewModel.ValidationError {
            // Handle duplicate items more gracefully
            if case .duplicateISBN = error {
                // Still show a success message but indicate it's a duplicate
                showSuccessToast(title: "\(book.volumeInfo.title) (already in collection)")
                
                // Still count it as "processed" for user awareness
                scanManager.addSuccessfulScan(
                    title: book.volumeInfo.title + " (duplicate)",
                    isbn: book.volumeInfo.industryIdentifiers?.first?.identifier
                )
                
                // Clear search field and refocus
                searchQuery = ""
                refocusSearchField()
                
                // Provide different feedback for duplicates
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.warning)
            } else {
                handleFailedScan(originalIsbn, reason: error.localizedDescription)
            }
        } catch {
            handleFailedScan(originalIsbn, reason: error.localizedDescription)
        }
    }
    
    private func handleFailedScan(_ code: String, reason: String) {
        // Add to failed scans
        scanManager.addFailedScan(code: code, reason: reason)
        
        // Clear search field
        searchQuery = ""
        
        // Announce the failure for VoiceOver users
        UIAccessibility.post(notification: .announcement, argument: "Scan failed: \(reason)")
        
        // Provide haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        
        // Re-focus the search field for the next scan
        refocusSearchField()
    }
    
    // First, add a method to check if a book already exists in the collection
    private func bookExistsInCollection(_ book: GoogleBook) -> Bool {
        // Create a temporary inventory item from the book
        let tempItem = createInventoryItem(from: book)
        
        // Use the InventoryViewModel's duplicate check method
        return inventoryViewModel.duplicateExists(tempItem)
    }
}

// New component for better-looking book results
struct BookResultCard: View {
    let book: GoogleBook
    let onSelect: (GoogleBook) -> Void
    @EnvironmentObject private var scanManager: ScanResultManager
    @EnvironmentObject private var inventoryViewModel: InventoryViewModel
    
    // Access the continuous mode state
    @Binding var continuousMode: Bool
    
    // Track when item is added
    @State private var isAdded = false
    @State private var buttonScale = 1.0
    
    // Check if item already exists in collection
    private var alreadyInCollection: Bool {
        // Create a temporary inventory item from the book
        let tempItem = InventoryItem(
            title: book.volumeInfo.title,
            type: .books, // Default type, sufficient for duplicate check
            series: nil,
            volume: nil,
            condition: .good,
            notes: nil,
            dateAdded: Date(),
            barcode: nil,
            thumbnailURL: nil,
            author: book.volumeInfo.authors?.first,
            manufacturer: nil,
            originalPublishDate: nil,
            publisher: book.volumeInfo.publisher,
            isbn: book.volumeInfo.industryIdentifiers?.first?.identifier,
            price: nil,
            purchaseDate: nil,
            synopsis: nil
        )
        
        // Use the InventoryViewModel's duplicate check method
        return inventoryViewModel.duplicateExists(tempItem)
    }
    
    var body: some View {
        Button(action: {
            // Show checkmark animation when pressed
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isAdded = true
                buttonScale = 1.2
            }
            
            // Slight delay for animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // Call the onSelect handler
                onSelect(book)
                
                // If not in continuous mode, keep the checkmark visible
                if !continuousMode {
                    isAdded = true
                } else {
                    // In continuous mode, reset after a brief delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation {
                            isAdded = false
                            buttonScale = 1.0
                        }
                    }
                }
            }
        }) {
            HStack(alignment: .top, spacing: 12) {
                // Book cover thumbnail
                if let thumbnailURLString = book.volumeInfo.imageLinks?.thumbnail,
                   let thumbnailURL = URL(string: thumbnailURLString.replacingOccurrences(of: "http://", with: "https://")) {
                    AsyncImage(url: thumbnailURL) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 90)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        } else if phase.error != nil {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(.systemGray4))
                                .frame(width: 60, height: 90)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundStyle(.secondary)
                                )
                        } else {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(.systemGray5))
                                .frame(width: 60, height: 90)
                                .overlay(
                                    ProgressView()
                                )
                        }
                    }
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .frame(width: 60, height: 90)
                        .overlay(
                            Image(systemName: "book.closed")
                                .foregroundStyle(.secondary)
                        )
                }
                
                // Book details
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.volumeInfo.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    if let author = book.volumeInfo.authors?.first {
                        Text(author)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    
                    HStack(spacing: 8) {
                        if let publisher = book.volumeInfo.publisher {
                            Text(publisher)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        
                        if let year = book.volumeInfo.publishedDate?.prefix(4) {
                            Text(String(year))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if let isbn = book.volumeInfo.industryIdentifiers?.first(where: { $0.type.contains("ISBN") })?.identifier {
                        Text("ISBN: \(isbn)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 4)
                
                Spacer()
                
                // Animated add button/checkmark or "already in collection" checkmark
                Group {
                    if isAdded {
                        // Show green checkmark when just added
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.green)
                            .scaleEffect(buttonScale)
                    } else if alreadyInCollection {
                        // Show green checkmark with message
                        VStack(alignment: .trailing, spacing: 2) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.green)
                            
                            Text("In Collection")
                                .font(.caption2)
                                .bold()
                                .foregroundColor(.green)
                        }
                    } else {
                        // Show plus button for new items
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.accentColor)
                    }
                }
                .padding([.top, .trailing], 6)
                .contentTransition(.symbolEffect(.replace))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray5), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
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
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Add Item Screen")
    }
} 
