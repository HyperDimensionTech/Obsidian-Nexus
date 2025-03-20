import SwiftUI

struct BatchMappingView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var scanManager: ScanResultManager
    @StateObject private var googleBooksService = GoogleBooksService()
    @StateObject private var isbnMappingService = ISBNMappingService()
    
    @State private var selectedISBN: String?
    @State private var searchQuery = ""
    @State private var searchResults: [GoogleBook] = []
    @State private var isSearching = false
    @State private var errorMessage = ""
    @State private var showingError = false
    @State private var successMessage = ""
    @State private var showingSuccess = false
    
    var body: some View {
        NavigationView {
            VStack {
                // ISBN selector
                List {
                    Section {
                        ForEach(scanManager.failedScans, id: \.code) { scan in
                            Button(action: {
                                selectedISBN = scan.code
                                // Pre-fill search with a cleaned version of the error if it might help
                                if scan.reason.contains("No book found") {
                                    searchQuery = ""
                                } else {
                                    searchQuery = ""
                                }
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(scan.code)
                                            .font(.headline)
                                        Text(scan.reason)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedISBN == scan.code {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            .contentShape(Rectangle())
                        }
                    } header: {
                        Text("Select ISBN to Map")
                    }
                    
                    if let isbn = selectedISBN {
                        Section {
                            TextField("Search for Book", text: $searchQuery)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                                .autocorrectionDisabled()
                                .onSubmit {
                                    performSearch()
                                }
                            
                            Button("Search") {
                                performSearch()
                            }
                            .disabled(searchQuery.isEmpty)
                        } header: {
                            Text("Search for Book to Map to ISBN \(isbn)")
                        }
                        
                        if isSearching {
                            Section {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                    Spacer()
                                }
                            }
                        } else if !searchResults.isEmpty {
                            Section("Select Book") {
                                ForEach(searchResults) { book in
                                    Button(action: {
                                        linkISBNToBook(isbn: isbn, book: book)
                                    }) {
                                        BookSearchResultRow(book: book)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Map Failed ISBNs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Success", isPresented: $showingSuccess) {
                Button("OK", role: .cancel) { 
                    // Remove the mapped ISBN from failed scans
                    if let index = scanManager.failedScans.firstIndex(where: { $0.code == selectedISBN }) {
                        scanManager.failedScans.remove(at: index)
                    }
                    
                    // Clear selection and search
                    selectedISBN = nil
                    searchQuery = ""
                    searchResults = []
                    
                    // If no more failed scans, dismiss
                    if scanManager.failedScans.isEmpty {
                        dismiss()
                    }
                }
            } message: {
                Text(successMessage)
            }
        }
    }
    
    private func performSearch() {
        guard !searchQuery.isEmpty else { return }
        
        isSearching = true
        googleBooksService.fetchBooks(query: searchQuery) { result in
            DispatchQueue.main.async {
                isSearching = false
                
                switch result {
                case .success(let books):
                    searchResults = books
                case .failure(let error):
                    errorMessage = "Error searching: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
    
    private func linkISBNToBook(isbn: String, book: GoogleBook) {
        // Create a mapping between the ISBN and the book
        isbnMappingService.addMapping(
            incorrectISBN: isbn,
            googleBooksId: book.id,
            title: book.volumeInfo.title
        )
        
        // Show success message
        successMessage = "ISBN \(isbn) linked to \(book.volumeInfo.title)"
        showingSuccess = true
        
        // Announce for VoiceOver users
        UIAccessibility.post(
            notification: .announcement,
            argument: "ISBN \(isbn) linked to \(book.volumeInfo.title)"
        )
    }
}

#Preview {
    let manager = ScanResultManager()
    manager.addFailedScan(code: "9781974723235", reason: "No book found")
    manager.addFailedScan(code: "9781974532365", reason: "API error")
    
    return BatchMappingView(scanManager: manager)
} 