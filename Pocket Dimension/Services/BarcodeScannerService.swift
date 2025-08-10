import AVFoundation
import UIKit

class BarcodeScannerService: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    @Published var scannedCode: String?
    @Published var isAuthorized = false
    @Published var error: String?
    @Published private(set) var isTorchOn = false
    @Published var detectedLocationId: UUID?
    
    private(set) var captureSession: AVCaptureSession?
    private let qrCodeService = QRCodeService.shared
    
    // Add a handler for location QR codes
    var onLocationDetected: ((UUID) -> Void)?
    
    // Add a flag to determine if we're scanning specifically for locations
    var isScanningForLocations = false
    
    override init() {
        super.init()
        checkPermissions()
    }
    
    private func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCaptureSession()
            isAuthorized = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted {
                        self?.setupCaptureSession()
                    }
                }
            }
        case .denied, .restricted:
            isAuthorized = false
            error = "Camera access is required to scan barcodes. Please enable it in Settings."
        @unknown default:
            isAuthorized = false
            error = "Unknown camera authorization status"
        }
    }
    
    func setupCaptureSession() {
        let session = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else {
            error = "Failed to initialize camera"
            return
        }
        
        guard session.canAddInput(videoInput) else {
            error = "Failed to add camera input"
            return
        }
        
        session.addInput(videoInput)
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        guard session.canAddOutput(metadataOutput) else {
            error = "Failed to add metadata output"
            return
        }
        
        session.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        metadataOutput.metadataObjectTypes = [.ean13, .ean8, .code128, .qr]
        
        captureSession = session
    }
    
    func startScanning() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    func stopScanning() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.stopRunning()
        }
    }
    
    func toggleTorch() {
        guard let device = AVCaptureDevice.default(for: .video) else { return }
        
        if device.hasTorch && device.isTorchAvailable {
            try? device.lockForConfiguration()
            
            if device.torchMode == .on {
                device.torchMode = .off
                isTorchOn = false
            } else {
                try? device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
                isTorchOn = true
            }
            
            device.unlockForConfiguration()
        }
    }
    
    func validateISBN(_ isbn: String) async throws -> Bool {
        // Use existing OpenLibrary or Google Books service to validate
        // Return true if book is found
        return false // Placeholder
    }
    
    // MARK: - AVCaptureMetadataOutputObjectsDelegate
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue else {
            return
        }
        
        // Handle the scanned code
        self.scannedCode = stringValue
        
        // If we're scanning for a location QR code, check if it's valid
        if isScanningForLocations {
            if let locationId = qrCodeService.parseLocationQRCode(from: stringValue) {
                self.detectedLocationId = locationId
                onLocationDetected?(locationId)
            }
        }
    }
} 