import SwiftUI

struct ISBNLinkingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var googleBooksService = GoogleBooksService()
    @StateObject private var isbnMappingService = ISBNMappingService(storage: .shared)
    
    let isbn: String
    let onBookSelected: (GoogleBook) -> Void
    
    @State private var searchQuery: String = ""
    @State private var searchResults: [GoogleBook] = []
    @State private var isSearching = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with explanation
                VStack(alignment: .leading, spacing: 12) {
                    Text("Link ISBN to Book")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    
                    Text("The ISBN \(isbn) wasn't found in the Google Books database. This can happen with reprinted books or manga volumes that have new ISBN numbers.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Search for the book by title to create a mapping between this ISBN and the correct book.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search by title", text: $searchQuery, onCommit: performSearch)
                        .accessibilityLabel("Search by title")
                        .accessibilityHint("Enter a book title to search")
                    
                    if !searchQuery.isEmpty {
                        Button(action: {
                            searchQuery = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .accessibilityLabel("Clear search")
                    }
                    
                    Button("Search") {
                        performSearch()
                    }
                    .disabled(searchQuery.isEmpty)
                    .accessibilityHint("Search for books with this title")
                }
                .padding()
                .background(Color(.systemBackground))
                
                // Results or loading indicator
                ZStack {
                    if isSearching {
                        VStack {
                            ProgressView()
                                .padding()
                                .accessibilityLabel("Searching")
                                .accessibilityHint("Please wait while we search for results")
                            
                            Text("Searching...")
                                .foregroundColor(.secondary)
                        }
                    } else if searchResults.isEmpty && !searchQuery.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "book.closed")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                                .padding(.top, 40)
                            
                            Text("No books found")
                                .font(.headline)
                            
                            Text("Try a different search term")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("No books found. Try a different search term.")
                    } else {
                        List {
                            ForEach(searchResults) { book in
                                BookSearchResultRow(book: book)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        linkISBNToBook(book)
                                    }
                            }
                        }
                        .accessibilityLabel("Search results")
                        .listStyle(PlainListStyle())
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationBarTitle("Link ISBN", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Skip") {
                    dismiss()
                }
                .accessibilityHint("Skip linking this ISBN and return to search")
            )
            .alert(isPresented: $showingError) {
                Alert(
                    title: Text("Error"),
                    message: Text(errorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private func performSearch() {
        guard !searchQuery.isEmpty else { return }
        
        isSearching = true
        googleBooksService.fetchBooks(query: searchQuery) { result in
            DispatchQueue.main.async {
                self.isSearching = false
                
                switch result {
                case .success(let books):
                    self.searchResults = books
                case .failure(let error):
                    self.errorMessage = "Error searching: \(error.localizedDescription)"
                    self.showingError = true
                }
            }
        }
    }
    
    private func linkISBNToBook(_ book: GoogleBook) {
        // Create a mapping between the ISBN and the book
        isbnMappingService.addMapping(
            incorrectISBN: isbn,
            googleBooksId: book.id,
            title: book.volumeInfo.title
        )
        
        // Call the completion handler with the selected book
        onBookSelected(book)
        
        // Dismiss the view
        dismiss()
        
        // Announce for VoiceOver users
        UIAccessibility.post(
            notification: .announcement,
            argument: "ISBN \(isbn) linked to \(book.volumeInfo.title)"
        )
    }
}

// Preview provider
struct ISBNLinkingView_Previews: PreviewProvider {
    static var previews: some View {
        ISBNLinkingView(
            isbn: "9781974712557",
            onBookSelected: { _ in }
        )
    }
} 