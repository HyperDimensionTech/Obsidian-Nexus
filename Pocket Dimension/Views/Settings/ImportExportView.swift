import SwiftUI

struct ImportExportView: View {
    @StateObject private var viewModel: ImportExportViewModel
    
    init() {
        _viewModel = StateObject(wrappedValue: ImportExportViewModel())
    }
    
    var body: some View {
        List {
            Section {
                Button {
                    Task {
                        await viewModel.exportData()
                    }
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up.fill")
                            .foregroundColor(.accentColor)
                        Text("Export Data")
                    }
                }
                .disabled(viewModel.isLoading)
                
                Button {
                    viewModel.showingImportPicker = true
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.down.fill")
                            .foregroundColor(.accentColor)
                        Text("Import Data")
                    }
                }
                .disabled(viewModel.isLoading)
                
                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            } header: {
                Text("Data Transfer")
            } footer: {
                Text("Export your data to a CSV file or import data from a previously exported file.")
            }
            
            if !viewModel.exportedFiles.isEmpty {
                Section {
                    ForEach(viewModel.exportedFiles, id: \.self) { fileURL in
                        ExportedFileRow(fileURL: fileURL) {
                            Task {
                                await viewModel.deleteExportedFile(fileURL)
                            }
                        }
                    }
                } header: {
                    Text("Exported Files")
                } footer: {
                    Text("Tap a file to share it. Swipe left to delete.")
                }
            }
        }
        .navigationTitle("Import/Export")
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .fileImporter(
            isPresented: $viewModel.showingImportPicker,
            allowedContentTypes: [.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            Task {
                await viewModel.handleImportResult(result)
            }
        }
    }
}

struct ExportedFileRow: View {
    let fileURL: URL
    let onDelete: () -> Void
    
    @State private var showingShareSheet = false
    
    private var fileDate: Date {
        (try? fileURL.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
    }
    
    private var fileSize: String {
        guard let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            return "Unknown"
        }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(fileSize))
    }
    
    var body: some View {
        Button(action: {
            showingShareSheet = true
        }) {
            HStack {
                VStack(alignment: .leading) {
                    Text(fileURL.lastPathComponent)
                        .font(.headline)
                        .foregroundColor(.primary)
                    HStack {
                        Text(fileDate.formatted(date: .long, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(fileSize)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(.accentColor)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ActivitySheet(items: [createTemporaryShareableFile()])
        }
    }
    
    private func createTemporaryShareableFile() -> URL {
        // Create a temporary file that can be shared
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(fileURL.lastPathComponent)
        
        // Remove existing temp file if it exists
        try? FileManager.default.removeItem(at: tempFile)
        
        // Copy to temp directory
        do {
            try FileManager.default.copyItem(at: fileURL, to: tempFile)
            return tempFile
        } catch {
            print("Failed to create shareable file: \(error)")
            return fileURL // Fallback to original
        }
    }
}

struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

#Preview {
    NavigationView {
        ImportExportView()
    }
} 