import SwiftUI

struct BackupSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: BackupSettingsViewModel
    
    init() {
        _viewModel = StateObject(wrappedValue: BackupSettingsViewModel())
    }
    
    var body: some View {
        List {
            Section {
                Button {
                    Task {
                        await viewModel.createBackup()
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.accentColor)
                        Text("Create Backup")
                    }
                }
                .disabled(viewModel.isLoading)
                
                Button {
                    Task {
                        await viewModel.saveToCloud()
                    }
                } label: {
                    HStack {
                        Image(systemName: "icloud.and.arrow.up.fill")
                            .foregroundColor(.accentColor)
                        Text("Save to Cloud")
                    }
                }
                .disabled(viewModel.isLoading)
                
                Button {
                    Task {
                        await viewModel.restoreFromCloud()
                    }
                } label: {
                    HStack {
                        Image(systemName: "icloud.and.arrow.down.fill")
                            .foregroundColor(.accentColor)
                        Text("Restore from Cloud")
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
                Text("Backup")
            } footer: {
                Text("Create a backup of your database. This will save all your items and locations.")
            }
            
            if !viewModel.backups.isEmpty {
                Section {
                    ForEach(viewModel.backups, id: \.self) { backupURL in
                        BackupRow(backupURL: backupURL) {
                            Task {
                                await viewModel.deleteBackup(backupURL)
                            }
                        } onRestore: {
                            viewModel.selectedBackup = backupURL
                            viewModel.showingRestoreConfirmation = true
                        }
                    }
                } header: {
                    Text("Available Backups")
                } footer: {
                    Text("Tap a backup to restore it. Swipe left to delete.")
                }
            }
        }
        .navigationTitle("Backup & Restore")
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .alert("Restore Backup", isPresented: $viewModel.showingRestoreConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Restore", role: .destructive) {
                Task {
                    await viewModel.restoreSelectedBackup()
                }
            }
        } message: {
            Text("This will replace your current data with the backup. This action cannot be undone.")
        }
        .task {
            await viewModel.loadBackups()
        }
        .onAppear {
            viewModel.dismiss = dismiss
        }
    }
}

struct BackupRow: View {
    let backupURL: URL
    let onDelete: () -> Void
    let onRestore: () -> Void
    
    private var backupDate: Date {
        (try? backupURL.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
    }
    
    private var backupSize: String {
        guard let fileSize = try? backupURL.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            return "Unknown"
        }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(fileSize))
    }
    
    var body: some View {
        Button {
            onRestore()
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(backupURL.lastPathComponent)
                        .font(.headline)
                    HStack {
                        Text(backupDate.formatted(date: .long, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(backupSize)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "arrow.clockwise.circle.fill")
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
    }
}

@MainActor
class BackupSettingsViewModel: ObservableObject {
    @Published private(set) var backups: [URL] = []
    @Published private(set) var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var showingRestoreConfirmation = false
    @Published var selectedBackup: URL?
    
    private let dataService = DataManagementService.shared
    var dismiss: DismissAction?
    
    init() {
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBackupSavedToCloud),
            name: .backupSavedToCloud,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBackupRestoredFromCloud),
            name: .backupRestoredFromCloud,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBackupError),
            name: .backupError,
            object: nil
        )
    }
    
    @objc private func handleBackupSavedToCloud() {
        // Handle successful cloud save
        Task {
            await loadBackups()
        }
    }
    
    @objc private func handleBackupRestoredFromCloud() {
        // Handle successful cloud restore
        dismiss?()
    }
    
    @objc private func handleBackupError(_ notification: Notification) {
        if let error = notification.object as? Error {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    func loadBackups() async {
        do {
            backups = try dataService.listBackups()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    func createBackup() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            _ = try await dataService.createBackup()
            await loadBackups()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    func deleteBackup(_ backupURL: URL) async {
        do {
            try dataService.deleteBackup(backupURL)
            await loadBackups()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    func restoreSelectedBackup() async {
        guard let backupURL = selectedBackup else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await dataService.restoreFromBackup(backupURL)
            dismiss?()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    func saveToCloud() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let backupURL = try await dataService.createBackup()
            try await dataService.saveBackupToCloud(backupURL)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    func restoreFromCloud() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await dataService.restoreFromCloud()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    NavigationView {
        BackupSettingsView()
    }
} 