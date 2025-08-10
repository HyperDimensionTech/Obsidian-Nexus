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
        Task { [weak self] in
            await self?.loadExportedFiles()
        }
    }
    
    deinit {
        print("🔴 ImportExportViewModel: Deallocating")
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
        do {
            let fileURL = try await dataService.exportData()
            await loadExportedFiles()
            
            // Present share sheet for the exported file
            await presentShareSheet(for: fileURL)
        } catch {
            self.errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }
    
    @MainActor
    private func presentShareSheet(for fileURL: URL) async {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return
        }
        
        let activityViewController = UIActivityViewController(
            activityItems: [fileURL], 
            applicationActivities: nil
        )
        
        // For iPad
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = rootViewController.view
            popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY, width: 0, height: 0)
        }
        
        rootViewController.present(activityViewController, animated: true)
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