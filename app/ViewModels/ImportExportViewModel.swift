import SwiftUI

@MainActor
class ImportExportViewModel: ObservableObject {
    @Published private(set) var exportedFiles: [URL] = []
    @Published private(set) var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var showingImportPicker = false
    
    private let dataService = DataManagementService.shared
    
    init() {
        Task {
            await loadExportedFiles()
        }
    }
    
    func loadExportedFiles() async {
        do {
            exportedFiles = try await dataService.getExportedFiles()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    func exportData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let fileURL = try await dataService.exportData()
            await loadExportedFiles()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    func deleteExportedFile(_ fileURL: URL) async {
        do {
            try await dataService.deleteExportedFile(fileURL)
            await loadExportedFiles()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    func handleImportResult(_ result: Result<[URL], Error>) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let urls = try result.get()
            guard let fileURL = urls.first else { return }
            try await dataService.importData(from: fileURL)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
} 