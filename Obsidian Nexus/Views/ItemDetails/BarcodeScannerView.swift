import SwiftUI

struct BarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = BarcodeScannerViewModel()
    @EnvironmentObject private var inventoryViewModel: InventoryViewModel
    @StateObject private var googleBooksService = GoogleBooksService()
    @StateObject private var isbnMappingService = ISBNMappingService()
    
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
    
    @State private var continuousScanEnabled = false
    @State private var scannedCount = 0
    @State private var failedScans: [(code: String, reason: String)] = []
    @State private var showingResults = false
    @State private var lastAddedTitle: String?
    @State private var showingAddConfirmation = false
    @State private var successfulScans: [(title: String, isbn: String?)] = []
    @State private var currentFailedISBN = ""
    @State private var showingLinkPrompt = false
    @State private var showingISBNLinking = false
    @State private var showingSuccessMessage = false
    @State private var successMessage = ""
    @State private var isDuplicate = false
    
    let onScan: (String) -> Void
    @Namespace private var animation
    
    var body: some View {
        ZStack {
            // Camera Preview
            if let session = viewModel.captureSession {
                CameraPreview(session: session)
                    .ignoresSafeArea()
            }
            
            // Success Message Overlay
            if showingSuccessMessage {
                VStack {
                    HStack {
                        Image(systemName: isDuplicate ? "checkmark.circle.fill" : "plus.circle.fill")
                            .foregroundColor(isDuplicate ? .orange : .green)
                            .font(.system(size: 24))
                        Text(successMessage)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                }
                .transition(.opacity)
                .onAppear {
                    // Auto-hide after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            showingSuccessMessage = false
                        }
                    }
                }
            }
            
            // Overlay Layout
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Top Bar - Simplified with SF Symbols and better spacing
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        Toggle(isOn: $continuousScanEnabled) {
                            Text("Continuous")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .toggleStyle(.button)
                        .tint(Color.blue)
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        
                        Button(action: { viewModel.toggleTorch() }) {
                            Image(systemName: viewModel.torchEnabled ? "flashlight.on.fill" : "flashlight.off.fill")
                                .font(.headline)
                                .foregroundColor(viewModel.torchEnabled ? .yellow : .white)
                                .frame(width: 36, height: 36)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Scan Frame - More modern with rounded corners and subtle animation
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.white.opacity(0.8), lineWidth: 3)
                            .frame(width: 250, height: 150)
                            .background(Color.black.opacity(0.1))
                        
                        // Add subtle scanning animation
                        if continuousScanEnabled {
                            Rectangle()
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [.clear, .blue.opacity(0.3), .clear]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                ))
                                .frame(width: 240, height: 3)
                                .offset(y: -60)
                                .animation(
                                    Animation.easeInOut(duration: 1.5)
                                        .repeatForever(autoreverses: true),
                                    value: UUID() // Force continuous animation
                                )
                        }
                    }
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    
                    Spacer()
                    
                    // Bottom Status Area - Cleaner with better visual hierarchy
                    VStack(spacing: 12) {
                        if continuousScanEnabled {
                            HStack(spacing: 16) {
                                VStack(alignment: .center) {
                                    Text("\(scannedCount)")
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("Scanned")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                
                                if let title = lastAddedTitle {
                                    VStack(alignment: .leading) {
                                        Text("Last Added:")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.8))
                                        Text(title)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.green)
                                            .lineLimit(1)
                                            .transition(.opacity)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(.horizontal)
                            
                            // Review button - More prominent with SF Symbol
                            if scannedCount > 0 {
                                Button(action: {
                                    showingResults = true
                                }) {
                                    HStack {
                                        Image(systemName: "list.bullet.clipboard")
                                        Text("Review Scanned Items")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                                .padding(.horizontal)
                                .padding(.top, 4)
                            }
                        }
                        
                        Text(continuousScanEnabled ? "Ready to scan next item..." : "Position barcode within frame")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.bottom, 8)
                    }
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(
                        // Gradient background for better readability
                        LinearGradient(
                            gradient: Gradient(colors: [Color.black.opacity(0.7), Color.black.opacity(0.5)]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                }
            }
        }
        .onAppear {
            viewModel.startScanning()
        }
        .onDisappear {
            if viewModel.torchEnabled {
                viewModel.toggleTorch()
            }
            viewModel.stopScanning()
        }
        .onChange(of: viewModel.scannedCode) { oldCode, newCode in
            guard let code = newCode else { return }
            
            if continuousScanEnabled {
                handleContinuousScan(code)
            } else {
                // Check for ISBN mappings first
                if let mapping = isbnMappingService.getMappingForISBN(code) {
                    // Use the Google Books ID from user mapping
                    googleBooksService.fetchBookById(mapping.correctGoogleBooksID) { result in
                        DispatchQueue.main.async {
                            switch result {
                            case .success(let book):
                                // Pass the mapped book's ISBN to maintain compatibility
                                onScan(book.volumeInfo.industryIdentifiers?.first?.identifier ?? code)
                                dismiss()
                            case .failure(_):
                                // If direct fetch fails, try a title search as fallback
                                self.searchByTitle(mapping.title, originalIsbn: code)
                            }
                        }
                    }
                } else {
                    // No mapping found, proceed with regular scan
                    onScan(code)
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showingResults) {
            ScanResultsView(
                scannedCount: scannedCount, 
                successfulScans: successfulScans,
                failedScans: failedScans,
                onContinue: {
                    showingResults = false
                },
                onFinish: {
                    showingResults = false
                    dismiss()
                }
            )
        }
        .sheet(isPresented: $showingISBNLinking) {
            ISBNLinkingView(
                isbn: currentFailedISBN,
                onBookSelected: { book in
                    // Process the selected book
                    self.processFoundBook(book, currentFailedISBN)
                    
                    // Announce success for VoiceOver users
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: "ISBN \(currentFailedISBN) linked to \(book.volumeInfo.title)"
                    )
                }
            )
        }
        .alert("ISBN Not Found", isPresented: $showingLinkPrompt) {
            Button("Link Now", role: .none) {
                showingISBNLinking = true
                showingLinkPrompt = false
            }
            Button("Skip", role: .cancel) {
                // Just continue scanning
                viewModel.clearScannedCode()
                viewModel.startScanning()
            }
        } message: {
            Text("Would you like to link this ISBN to a book in Google Books?")
        }
        .toolbar {
            if continuousScanEnabled {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Review (\(scannedCount))") {
                        showingResults = true
                    }
                    .disabled(scannedCount == 0)
                }
            }
        }
    }
    
    private func handleContinuousScan(_ code: String) {
        // Stop scanning while processing
        viewModel.stopScanning()
        
        // First check user-defined mappings
        if let mapping = isbnMappingService.getMappingForISBN(code) {
            // Use the Google Books ID from user mapping
            googleBooksService.fetchBookById(mapping.correctGoogleBooksID) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let book):
                        self.processFoundBook(book, code)
                        // Resume scanning after processing
                        self.viewModel.startScanning()
                    case .failure(_):
                        // If direct fetch fails, try a title search as fallback
                        self.searchByTitle(mapping.title, originalIsbn: code)
                    }
                }
            }
            return
        }
        
        // If no mapping found, perform a regular ISBN search
        googleBooksService.fetchBooksByISBN(code) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let books):
                    if let book = books.first {
                        self.processFoundBook(book, code)
                    } else {
                        self.handleNoBookFound(code)
                    }
                case .failure(let error):
                    self.handleFailedScan(code, reason: error.localizedDescription)
                }
                
                // Resume scanning after processing
                self.viewModel.startScanning()
            }
        }
    }
    
    private func processFoundBook(_ book: GoogleBook, _ isbnQuery: String) {
        do {
            // Check if item already exists
            let existingItem = inventoryViewModel.items.first { item in
                item.isbn == isbnQuery || 
                (item.type == .manga && item.title == book.volumeInfo.title)
            }
            
            if existingItem != nil {
                isDuplicate = true
                successMessage = "\(book.volumeInfo.title) already in collection"
                withAnimation {
                    showingSuccessMessage = true
                }
                return
            }
            
            // Create the item with proper classification
            let newItem = inventoryViewModel.createItemFromGoogleBook(book)
            
            // Ensure the item type is correctly set based on publisher
            if let publisher = book.volumeInfo.publisher?.lowercased(), 
               BarcodeScannerView.mangaPublishers.contains(where: { publisher.contains($0) }) {
                // This is a manga - make sure it's classified as such
                var updatedItem = newItem
                updatedItem.type = .manga
                try inventoryViewModel.addItem(updatedItem)
            } else {
                // Regular book or already classified correctly
                try inventoryViewModel.addItem(newItem)
            }
            
            scannedCount += 1
            lastAddedTitle = book.volumeInfo.title
            successfulScans.append((
                title: book.volumeInfo.title,
                isbn: book.volumeInfo.industryIdentifiers?.first?.identifier
            ))
            
            // Show success message
            isDuplicate = false
            successMessage = "Added \(book.volumeInfo.title)"
            withAnimation {
                showingSuccessMessage = true
            }
            
            // Provide feedback
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            
            // Announce for VoiceOver users
            UIAccessibility.post(notification: .announcement, argument: "Added \(book.volumeInfo.title). Ready for next scan.")
            
        } catch {
            handleFailedScan(isbnQuery, reason: error.localizedDescription)
        }
    }
    
    private func handleNoBookFound(_ isbnQuery: String, error: String? = nil) {
        let reason = error ?? "No book found"
        
        // Store the failed ISBN for later use
        currentFailedISBN = isbnQuery
        
        // Add to failed scans
        failedScans.append((code: isbnQuery, reason: reason))
        
        // Show link prompt
        showingLinkPrompt = true
        
        // Announce the failure for VoiceOver users
        UIAccessibility.post(notification: .announcement, argument: "Scan failed: \(reason)")
    }
    
    private func handleFailedScan(_ code: String, reason: String) {
        failedScans.append((code, reason))
        
        // Announce the failure for VoiceOver users
        UIAccessibility.post(notification: .announcement, argument: "Scan failed: \(reason)")
        
        // Provide haptic feedback
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
    
    private func searchByTitle(_ title: String, originalIsbn: String) {
        googleBooksService.fetchBooks(query: title) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let books):
                    if let book = books.first {
                        self.processFoundBook(book, originalIsbn)
                    } else {
                        self.handleNoBookFound(originalIsbn, error: "No book found for mapped title")
                    }
                case .failure(_):
                    self.handleNoBookFound(originalIsbn, error: "Failed to search by title")
                }
                
                // Resume scanning after processing
                self.viewModel.startScanning()
            }
        }
    }
}

struct ScanResultsView: View {
    @Environment(\.dismiss) private var dismiss
    let scannedCount: Int
    let successfulScans: [(title: String, isbn: String?)]
    let failedScans: [(code: String, reason: String)]
    let onContinue: () -> Void
    let onFinish: () -> Void
    
    var body: some View {
        NavigationView {
            List {
                Section("Summary") {
                    Text("Successfully scanned: \(scannedCount)")
                    Text("Failed scans: \(failedScans.count)")
                }
                
                if !successfulScans.isEmpty {
                    Section("Successfully Scanned") {
                        ForEach(successfulScans, id: \.title) { scan in
                            VStack(alignment: .leading) {
                                Text(scan.title)
                                    .font(.headline)
                                if let isbn = scan.isbn {
                                    Text("ISBN: \(isbn)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                
                if !failedScans.isEmpty {
                    Section("Failed Scans") {
                        ForEach(failedScans, id: \.code) { scan in
                            VStack(alignment: .leading) {
                                Text("ISBN: \(scan.code)")
                                    .font(.subheadline)
                                Text("Error: \(scan.reason)")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Scan Results")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Continue Scanning") {
                        onContinue()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Finish") {
                        onFinish()
                    }
                }
            }
        }
    }
} 