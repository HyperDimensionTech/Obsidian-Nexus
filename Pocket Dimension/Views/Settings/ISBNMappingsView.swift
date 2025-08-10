import SwiftUI

struct ISBNMappingsView: View {
    @EnvironmentObject private var serviceContainer: ServiceContainer
    @State private var showingDeleteAlert = false
    @State private var mappingToDelete: ISBNMapping?
    @State private var showingAddMapping = false
    
    private var isbnMappingService: ISBNMappingService {
        serviceContainer.isbnMappingService
    }
    
    private var googleBooksService: GoogleBooksService {
        serviceContainer.googleBooksService
    }
    
    var body: some View {
        List {
            Section(header: Text("About ISBN Mappings")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ISBN mappings help the app recognize books that have different ISBN numbers than what's in the Google Books database.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("This is common with reprinted manga volumes that receive new ISBN numbers.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            if isbnMappingService.mappings.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "barcode")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                            .padding(.top, 20)
                        
                        Text("No ISBN Mappings")
                            .font(.headline)
                        
                        Text("Add mappings manually or they will be created when you link failed ISBN scans to books.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                Section(header: Text("Your ISBN Mappings")) {
                    ForEach(isbnMappingService.mappings) { mapping in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(mapping.title)
                                    .font(.headline)
                                
                                Spacer()
                                
                                if mapping.isReprint {
                                    Text("Reprint")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.2))
                                        .foregroundColor(.blue)
                                        .cornerRadius(4)
                                }
                            }
                            
                            Text("ISBN: \(mapping.incorrectISBN)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("Added: \(formattedDate(mapping.dateAdded))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                        .contextMenu {
                            Button(role: .destructive) {
                                mappingToDelete = mapping
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                mappingToDelete = mapping
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("ISBN Mappings")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddMapping = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
        }
        .sheet(isPresented: $showingAddMapping) {
            NavigationView {
                AddISBNMappingView(isbnMappingService: isbnMappingService)
            }
        }
        .alert("Delete Mapping?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let mapping = mappingToDelete {
                    isbnMappingService.removeMapping(for: mapping.incorrectISBN)
                }
            }
        } message: {
            if let mapping = mappingToDelete {
                Text("Are you sure you want to delete the mapping for \"\(mapping.title)\"? This ISBN will no longer be recognized.")
            } else {
                Text("Are you sure you want to delete this mapping?")
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct AddISBNMappingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var serviceContainer: ServiceContainer
    @ObservedObject var isbnMappingService: ISBNMappingService
    @StateObject private var barcodeScannerViewModel = BarcodeScannerViewModel()
    
    @State private var isbn = ""
    @State private var searchQuery = ""
    @State private var isSearching = false
    @State private var searchResults: [GoogleBook] = []
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var showingScanner = false
    
    private var googleBooksService: GoogleBooksService {
        serviceContainer.googleBooksService
    }
    
    var body: some View {
        List {
            Section {
                HStack {
                    TextField("ISBN to Map", text: $isbn)
                        .keyboardType(.numberPad)
                        .textContentType(.none)
                        .autocorrectionDisabled()
                    
                    Button(action: { showingScanner = true }) {
                        Image(systemName: "barcode.viewfinder")
                            .foregroundColor(.blue)
                    }
                }
                
                TextField("Search for Book", text: $searchQuery)
                    .textContentType(.none)
                    .autocorrectionDisabled()
                    .onSubmit {
                        searchBooks()
                    }
            } header: {
                Text("ISBN Mapping Details")
            } footer: {
                Text("Enter the ISBN you want to map and search for the correct book in Google Books. Use the camera button to scan an ISBN barcode.")
            }
            
            if isSearching {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                }
            } else if !searchResults.isEmpty {
                Section("Search Results") {
                    ForEach(searchResults, id: \.id) { book in
                        Button {
                            addMapping(book)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(book.volumeInfo.title)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                if let authors = book.volumeInfo.authors {
                                    Text(authors.joined(separator: ", "))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let isbn = book.volumeInfo.industryIdentifiers?.first?.identifier {
                                    Text("ISBN: \(isbn)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Add ISBN Mapping")
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
            Text(errorMessage ?? "An unknown error occurred")
        }
        .sheet(isPresented: $showingScanner) {
            ScannerSheet(onScan: { scannedCode in
                isbn = scannedCode
                showingScanner = false
            })
        }
    }
    
    private func searchBooks() {
        guard !searchQuery.isEmpty else { return }
        
        isSearching = true
        searchResults = []
        
        googleBooksService.fetchBooks(query: searchQuery) { result in
            DispatchQueue.main.async {
                isSearching = false
                
                switch result {
                case .success(let books):
                    searchResults = books
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    private func addMapping(_ book: GoogleBook) {
        guard !isbn.isEmpty else {
            errorMessage = "Please enter an ISBN to map"
            showingError = true
            return
        }
        
        // Create the mapping
        isbnMappingService.addMapping(
            incorrectISBN: isbn,
            googleBooksId: book.id,
            title: book.volumeInfo.title,
            isReprint: true
        )
        
        // Show success feedback
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        
        // Dismiss the sheet
        dismiss()
    }
}

// Simple scanner sheet just for capturing ISBN barcodes
struct ScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = BarcodeScannerViewModel()
    let onScan: (String) -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                if let session = viewModel.captureSession {
                    CameraPreview(session: session)
                        .ignoresSafeArea()
                }
                
                VStack {
                    Spacer()
                    
                    // Scan Frame
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.8), lineWidth: 3)
                        .frame(width: 250, height: 150)
                        .background(Color.black.opacity(0.1))
                    
                    Spacer()
                    
                    Text("Position barcode within frame")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                }
            }
            .onAppear {
                viewModel.startScanning()
            }
            .onDisappear {
                viewModel.stopScanning()
            }
            .onChange(of: viewModel.scannedCode) { _, code in
                if let code = code {
                    onScan(code)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .navigationTitle("Scan ISBN")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    NavigationView {
        ISBNMappingsView()
    }
} 