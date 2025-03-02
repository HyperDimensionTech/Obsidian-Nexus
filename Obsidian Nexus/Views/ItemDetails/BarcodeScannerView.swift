import SwiftUI

struct BarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = BarcodeScannerViewModel()
    @EnvironmentObject private var inventoryViewModel: InventoryViewModel
    @StateObject private var googleBooksService = GoogleBooksService()
    @State private var continuousScanEnabled = false
    @State private var scannedCount = 0
    @State private var failedScans: [(code: String, reason: String)] = []
    @State private var showingResults = false
    @State private var lastAddedTitle: String?
    @State private var showingAddConfirmation = false
    @State private var successfulScans: [(title: String, isbn: String?)] = []
    
    let onScan: (String) -> Void
    @Namespace private var animation
    
    var body: some View {
        ZStack {
            // Camera Preview
            if let session = viewModel.captureSession {
                CameraPreview(session: session)
                    .ignoresSafeArea()
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
                onScan(code) // Original behavior for manual mode
                dismiss()
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
        
        // Define manga publishers list here since we can't access the private one in AddItemView
        let mangaPublishers = [
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
        
        // Search and add
        googleBooksService.fetchBooks(query: "isbn:\(code)") { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let books):
                    if let book = books.first {
                        do {
                            // Create the item with proper classification
                            let newItem = inventoryViewModel.createItemFromGoogleBook(book)
                            
                            // Ensure the item type is correctly set based on publisher
                            if let publisher = book.volumeInfo.publisher?.lowercased(), 
                               mangaPublishers.contains(where: { publisher.contains($0) }) {
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
                            
                            // Show confirmation briefly
                            withAnimation {
                                showingAddConfirmation = true
                            }
                            
                            // Clear after delay and prepare for next scan
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation {
                                    showingAddConfirmation = false
                                    lastAddedTitle = nil
                                }
                                // Resume scanning
                                viewModel.clearScannedCode()
                                viewModel.startScanning()
                            }
                        } catch {
                            failedScans.append((code, error.localizedDescription))
                            viewModel.clearScannedCode()
                            viewModel.startScanning()
                        }
                    } else {
                        failedScans.append((code, "No book found"))
                        viewModel.clearScannedCode()
                        viewModel.startScanning()
                    }
                case .failure(let error):
                    failedScans.append((code, error.localizedDescription))
                    viewModel.clearScannedCode()
                    viewModel.startScanning()
                }
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