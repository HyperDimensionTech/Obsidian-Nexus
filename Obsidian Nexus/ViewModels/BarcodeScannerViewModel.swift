import SwiftUI
import AVFoundation
import Combine

@MainActor
class BarcodeScannerViewModel: ObservableObject {
    @Published private(set) var scannedCode: String?
    @Published private(set) var isAuthorized = false
    @Published private(set) var error: String?
    @Published private(set) var isScanning = false
    
    private let scannerService: BarcodeScannerService
    private var cancellables = Set<AnyCancellable>()
    
    init(scannerService: BarcodeScannerService = BarcodeScannerService()) {
        self.scannerService = scannerService
        setupBindings()
    }
    
    private func setupBindings() {
        // Forward service updates to view model
        scannerService.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.scannedCode = self?.scannerService.scannedCode
                    self?.isAuthorized = self?.scannerService.isAuthorized ?? false
                    self?.error = self?.scannerService.error
                }
            }
            .store(in: &cancellables)
    }
    
    var captureSession: AVCaptureSession? {
        scannerService.captureSession
    }
    
    func startScanning() {
        isScanning = true
        scannerService.startScanning()
    }
    
    func stopScanning() {
        isScanning = false
        scannerService.stopScanning()
    }
    
    func clearScannedCode() {
        scannedCode = nil
    }
} 