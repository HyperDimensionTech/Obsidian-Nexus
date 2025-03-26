import Foundation

/// A centralized manager for scan results from both camera and text-based scanning.
class ScanResultManager: ObservableObject {
    @Published var successfulScans: [(title: String, isbn: String?)] = []
    @Published var failedScans: [(code: String, reason: String)] = []
    @Published var totalScannedCount: Int = 0
    @Published var lastAddedTitle: String?
    
    /// Add a successful scan to the results
    func addSuccessfulScan(title: String, isbn: String?) {
        DispatchQueue.main.async {
            self.successfulScans.append((title: title, isbn: isbn))
            self.totalScannedCount += 1
            self.lastAddedTitle = title
        }
    }
    
    /// Add a failed scan to the results
    func addFailedScan(code: String, reason: String) {
        DispatchQueue.main.async {
            self.failedScans.append((code: code, reason: reason))
        }
    }
    
    /// Clear all scan results
    func clearAll() {
        DispatchQueue.main.async {
            self.successfulScans = []
            self.failedScans = []
            self.totalScannedCount = 0
            self.lastAddedTitle = nil
        }
    }
    
    /// Clear only successful scans
    func clearSuccessful() {
        DispatchQueue.main.async {
            self.totalScannedCount -= self.successfulScans.count
            self.successfulScans = []
            self.lastAddedTitle = nil
        }
    }
    
    /// Clear only failed scans
    func clearFailed() {
        DispatchQueue.main.async {
            self.failedScans = []
        }
    }
    
    /// Check if there are any scan results
    var hasResults: Bool {
        return !successfulScans.isEmpty || !failedScans.isEmpty
    }
} 