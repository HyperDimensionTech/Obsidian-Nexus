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
                    // Top Bar
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        Toggle("Continuous", isOn: $continuousScanEnabled)
                            .toggleStyle(.button)
                            .tint(.blue)
                            .foregroundColor(.white)
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                        
                        Button(action: { viewModel.toggleTorch() }) {
                            Image(systemName: viewModel.torchEnabled ? "flashlight.on.fill" : "flashlight.off.fill")
                                .font(.title2)
                                .foregroundColor(viewModel.torchEnabled ? .yellow : .white)
                                .padding()
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Fixed Position Scan Frame
                    Rectangle()
                        .strokeBorder(.white, lineWidth: 2)
                        .frame(width: 250, height: 150)
                        .background(Color.black.opacity(0.1))
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    
                    Spacer()
                    
                    // Bottom Status Area
                    VStack(spacing: 8) {
                        if continuousScanEnabled {
                            Text("Scanned: \(scannedCount)")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            if let title = lastAddedTitle {
                                Text("Added: \(title)")
                                    .foregroundColor(.green)
                                    .transition(.opacity)
                            }
                        }
                        
                        Text(continuousScanEnabled ? "Ready to scan next item..." : "Position barcode within frame")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .frame(height: 100)
                    .background(.ultraThinMaterial)
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
                failedScans: failedScans
            )
        }
        .toolbar {
            if continuousScanEnabled {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Review (\(scannedCount))") {
                        showingResults = true
                    }
                }
            }
        }
    }
    
    private func handleContinuousScan(_ code: String) {
        // Stop scanning while processing
        viewModel.stopScanning()
        
        // Search and add
        googleBooksService.fetchBooks(query: "isbn:\(code)") { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let books):
                    if let book = books.first {
                        do {
                            let newItem = inventoryViewModel.createItemFromGoogleBook(book)
                            try inventoryViewModel.addItem(newItem)
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
} 