import SwiftUI

struct BarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = BarcodeScannerViewModel()
    @EnvironmentObject private var inventoryViewModel: InventoryViewModel
    @EnvironmentObject private var serviceContainer: ServiceContainer
    @EnvironmentObject private var scanManager: ScanResultManager
    
    private var googleBooksService: GoogleBooksService {
        serviceContainer.googleBooksService
    }
    
    private var isbnMappingService: ISBNMappingService {
        serviceContainer.isbnMappingService
    }
    
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
    @State private var showingResults = false
    @State private var currentFailedISBN = ""
    @State private var showingLinkPrompt = false
    @State private var showingISBNLinking = false
    @State private var showingSuccessMessage = false
    @State private var successMessage = ""
    @State private var isDuplicate = false
    @State private var isProcessing = false
    @State private var processingStatus = "Ready to scan next item..."
    
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
                        .onChange(of: continuousScanEnabled) { _, isEnabled in
                            processingStatus = isEnabled ? "Ready to scan next item..." : "Position barcode within frame"
                        }
                        
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
                                // Successful scans counter
                                VStack(alignment: .center) {
                                    Text("\(scanManager.successfulScans.count)")
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("Successful")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                
                                if let title = scanManager.lastAddedTitle {
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
                                
                                // Failed scans counter
                                VStack(alignment: .center) {
                                    Text("\(scanManager.failedScans.count)")
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("Failed")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            .padding(.horizontal)
                            
                            // Review button - More prominent with SF Symbol
                            if scanManager.successfulScans.count > 0 || scanManager.failedScans.count > 0 {
                                Button(action: {
                                    showingResults = true
                                }) {
                                    HStack {
                                        Image(systemName: "list.bullet.clipboard")
                                        Text("Review Scanned Items (\(scanManager.successfulScans.count + scanManager.failedScans.count))")
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
                        
                        Text(processingStatus)
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
            processingStatus = continuousScanEnabled ? "Ready to scan next item..." : "Position barcode within frame"
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
                scanManager: scanManager,
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
                    Button("Review (\(scanManager.successfulScans.count + scanManager.failedScans.count))") {
                        showingResults = true
                    }
                    .disabled(scanManager.successfulScans.isEmpty && scanManager.failedScans.isEmpty)
                }
            }
        }
    }
    
    private func handleContinuousScan(_ code: String) {
        // Stop scanning while processing
        viewModel.stopScanning()
        // Update processing status
        isProcessing = true
        processingStatus = "Processing scan..."
        
        // First check user-defined mappings
        if let mapping = isbnMappingService.getMappingForISBN(code) {
            // Use the Google Books ID from user mapping
            googleBooksService.fetchBookById(mapping.correctGoogleBooksID) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let book):
                        self.processFoundBook(book, code)
                        // Show wait message
                        self.processingStatus = "Waiting for next scan..."
                        // Resume scanning after processing with a delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self.isProcessing = false
                            self.processingStatus = "Ready to scan next item..."
                            self.viewModel.startScanning()
                        }
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
                
                // Show wait message
                self.processingStatus = "Waiting for next scan..."
                // Resume scanning after processing with a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.isProcessing = false
                    self.processingStatus = "Ready to scan next item..."
                    self.viewModel.startScanning()
                }
            }
        }
    }
    
    private func searchByTitle(_ title: String, originalIsbn: String) {
        // Update processing status
        isProcessing = true
        processingStatus = "Searching for title..."
        
        googleBooksService.fetchBooks(query: title) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let books):
                    if let book = books.first {
                        self.processFoundBook(book, originalIsbn)
                    } else {
                        self.handleNoBookFound(originalIsbn)
                    }
                case .failure(let error):
                    self.handleFailedScan(originalIsbn, reason: error.localizedDescription)
                }
                
                // Show wait message
                self.processingStatus = "Waiting for next scan..."
                // Resume scanning with a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.isProcessing = false
                    self.processingStatus = "Ready to scan next item..."
                    self.viewModel.startScanning()
                }
            }
        }
    }
    
    private func processFoundBook(_ book: GoogleBook, _ originalIsbn: String) {
        do {
            // Create a new item from the Google Book
            let newItem = inventoryViewModel.createItemFromGoogleBook(book)
            
            // Add it to the inventory (this may automatically merge duplicates)
            try inventoryViewModel.addItem(newItem)
            
            // Update scan count and display
            scanManager.addSuccessfulScan(
                title: book.volumeInfo.title,
                isbn: book.volumeInfo.industryIdentifiers?.first?.identifier
            )
            
            // Show success toast
            successMessage = "Added: \(book.volumeInfo.title)"
            isDuplicate = false
            withAnimation {
                showingSuccessMessage = true
            }
            
            // Vibrate
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
        } catch let error as InventoryViewModel.ValidationError {
            // Handle enhanced duplicate detection
            if error.isDuplicateMerged {
                // Item was successfully merged
                successMessage = "Updated: \(book.volumeInfo.title)"
                isDuplicate = true  // Use duplicate styling but success message
                withAnimation {
                    showingSuccessMessage = true
                }
                
                // Count as successful (merged) scan
                scanManager.addSuccessfulScan(
                    title: book.volumeInfo.title + " (updated)",
                    isbn: book.volumeInfo.industryIdentifiers?.first?.identifier
                )
                
                // Vibrate for success (but slightly different)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                
            } else if case .duplicateISBN = error {
                // Traditional duplicate handling
                successMessage = "Already in collection: \(book.volumeInfo.title)"
                isDuplicate = true
                withAnimation {
                    showingSuccessMessage = true
                }
                
                // Still count it as "processed" for user awareness
                scanManager.addSuccessfulScan(
                    title: book.volumeInfo.title + " (duplicate)",
                    isbn: book.volumeInfo.industryIdentifiers?.first?.identifier
                )
                
                // Vibrate differently for duplicates
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.warning)
                
            } else {
                // Other validation errors
                handleFailedScan(originalIsbn, reason: error.localizedDescription)
            }
        } catch {
            handleFailedScan(originalIsbn, reason: error.localizedDescription)
        }
    }
    
    private func handleNoBookFound(_ isbn: String) {
        // Store the ISBN for mapping
        currentFailedISBN = isbn
        
        // Add to failed scans
        scanManager.addFailedScan(code: isbn, reason: "No book found")
        
        // Show mapping prompt
        showingLinkPrompt = true
    }
    
    private func handleFailedScan(_ code: String, reason: String) {
        // Add to failed scans
        scanManager.addFailedScan(code: code, reason: reason)
        
        // Announce failure
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        
        // Clear scanner for next code
        viewModel.clearScannedCode()
    }
}

// ScanResultsView implementation removed - now using the shared component 