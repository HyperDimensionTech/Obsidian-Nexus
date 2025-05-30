import SwiftUI
import AVFoundation
import Combine

@MainActor
class BarcodeScannerViewModel: NSObject, ObservableObject {
    @Published var scannedCode: String?
    @Published private(set) var isAuthorized = false
    @Published var error: String?
    @Published var isScanning = false
    
    @Published private(set) var scanHistory: [String] = []
    @Published private(set) var torchEnabled = false
    @Published private(set) var validationStatus: ValidationStatus = .none
    
    enum ValidationStatus {
        case none
        case validating
        case valid(String)
        case invalid(String)
    }
    
    private let scannerService: BarcodeScannerService
    private var cancellables = Set<AnyCancellable>()
    
    init(scannerService: BarcodeScannerService = BarcodeScannerService()) {
        self.scannerService = scannerService
        super.init()
        setupBindings()
    }
    
    private func setupBindings() {
        // Add torch state binding
        scannerService.$isTorchOn
            .sink { [weak self] isTorchOn in
                self?.torchEnabled = isTorchOn
            }
            .store(in: &cancellables)
        
        // Forward service updates to view model
        scannerService.objectWillChange
            .sink { [weak self] _ in
                self?.scannedCode = self?.scannerService.scannedCode
                self?.isAuthorized = self?.scannerService.isAuthorized ?? false
                self?.error = self?.scannerService.error
            }
            .store(in: &cancellables)
    }
    
    var captureSession: AVCaptureSession? {
        scannerService.captureSession
    }
    
    func startScanning() {
        isScanning = true
        validationStatus = .none
        scannerService.startScanning()
    }
    
    func stopScanning() {
        isScanning = false
        scannerService.stopScanning()
    }
    
    func toggleTorch() {
        scannerService.toggleTorch()
        torchEnabled = scannerService.isTorchOn
    }
    
    func validateScannedCode(_ code: String) async {
        validationStatus = .validating
        
        // Check if it's a valid ISBN
        if code.count == 13 || code.count == 10 {
            do {
                // Try to fetch book details
                let isValid = try await scannerService.validateISBN(code)
                if isValid {
                    validationStatus = .valid(code)
                    addToHistory(code)
                } else {
                    validationStatus = .invalid("No book found with this ISBN")
                }
            } catch {
                validationStatus = .invalid(error.localizedDescription)
            }
        } else {
            validationStatus = .invalid("Invalid barcode format")
        }
    }
    
    private func addToHistory(_ code: String) {
        if !scanHistory.contains(code) {
            scanHistory.insert(code, at: 0)
            if scanHistory.count > 10 { // Keep last 10 scans
                scanHistory.removeLast()
            }
        }
    }
    
    func clearHistory() {
        scanHistory.removeAll()
    }
    
    func clearScannedCode() {
        scannedCode = nil
    }
} 