import SwiftUI

struct ScanResultsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var scanManager: ScanResultManager
    @State private var showingClearConfirmation = false
    @State private var showingBatchMapping = false
    @State private var showingISBNLinking = false
    @State private var selectedISBNForMapping: String = ""
    
    let onContinue: () -> Void
    let onFinish: () -> Void
    
    var body: some View {
        NavigationView {
            List {
                Section("Summary") {
                    Text("Successfully scanned: \(scanManager.successfulScans.count)")
                    Text("Failed scans: \(scanManager.failedScans.count)")
                }
                
                if !scanManager.successfulScans.isEmpty {
                    Section {
                        ForEach(scanManager.successfulScans, id: \.title) { scan in
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
                    } header: {
                        HStack {
                            Text("Successfully Scanned")
                            Spacer()
                            if !scanManager.successfulScans.isEmpty {
                                Button(action: {
                                    scanManager.clearSuccessful()
                                }) {
                                    Label("Clear", systemImage: "trash")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                
                if !scanManager.failedScans.isEmpty {
                    Section {
                        ForEach(scanManager.failedScans, id: \.code) { scan in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("ISBN: \(scan.code)")
                                        .font(.subheadline)
                                    Text("Error: \(scan.reason)")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    selectedISBNForMapping = scan.code
                                    showingISBNLinking = true
                                }) {
                                    Image(systemName: "link.badge.plus")
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Map ISBN \(scan.code)")
                            }
                        }
                        
                        Button("Map All Failed ISBNs") {
                            showingBatchMapping = true
                        }
                        .buttonStyle(.bordered)
                        .padding(.vertical, 5)
                    } header: {
                        HStack {
                            Text("Failed Scans")
                            Spacer()
                            if !scanManager.failedScans.isEmpty {
                                Button(action: {
                                    scanManager.clearFailed()
                                }) {
                                    Label("Clear", systemImage: "trash")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Scan Results")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                        onFinish()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue") {
                        dismiss()
                        onContinue()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showingClearConfirmation = true
                    }) {
                        Label("Clear All", systemImage: "trash")
                    }
                    .disabled(!scanManager.hasResults)
                }
            }
            .confirmationDialog(
                "Clear All Results",
                isPresented: $showingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All Results", role: .destructive) {
                    scanManager.clearAll()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will remove all successful and failed scan results.")
            }
            .sheet(isPresented: $showingBatchMapping) {
                BatchMappingView(scanManager: scanManager)
            }
            .sheet(isPresented: $showingISBNLinking) {
                ISBNLinkingView(
                    isbn: selectedISBNForMapping,
                    onBookSelected: { book in
                        // Remove this ISBN from failed scans after successful mapping
                        if let index = scanManager.failedScans.firstIndex(where: { $0.code == selectedISBNForMapping }) {
                            scanManager.failedScans.remove(at: index)
                        }
                        
                        // Add as a successful scan
                        scanManager.addSuccessfulScan(
                            title: book.volumeInfo.title, 
                            isbn: book.volumeInfo.industryIdentifiers?.first?.identifier
                        )
                    }
                )
            }
        }
    }
}

#Preview {
    let manager = ScanResultManager()
    // Add some sample data
    manager.addSuccessfulScan(title: "One Piece Vol. 1", isbn: "9781569319017")
    manager.addSuccessfulScan(title: "Naruto Vol. 1", isbn: "9781569319000")
    manager.addFailedScan(code: "1234567890123", reason: "No book found")
    
    return ScanResultsView(
        scanManager: manager,
        onContinue: {},
        onFinish: {}
    )
} 