import SwiftUI
import AVFoundation

struct LocationQRScannerView: View {
    @StateObject private var scannerService = BarcodeScannerService()
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @Environment(\.dismiss) var dismiss
    
    @State private var showingLocationDetail = false
    @State private var scannedLocation: StorageLocation?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isScanning = true
    
    var body: some View {
        ZStack {
            // Camera preview
            if let captureSession = scannerService.captureSession {
                CameraPreview(session: captureSession)
                    .ignoresSafeArea()
            } else {
                Color.black
                    .ignoresSafeArea()
                Text("Camera not available")
                    .foregroundColor(.white)
            }
            
            VStack {
                Spacer()
                
                // Scanner overlay
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Color.white, lineWidth: 3)
                    .frame(width: 250, height: 250)
                    .background(Color.black.opacity(0.1))
                    .overlay(
                        Image(systemName: "qrcode.viewfinder")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .foregroundColor(Color.white.opacity(0.5))
                    )
                    .padding(.bottom, 40)
                
                Text("Scan a Location QR Code")
                    .font(.headline)
                    .foregroundColor(.white)
                    .shadow(radius: 5)
                
                Spacer()
                
                // Torch button
                Button(action: { scannerService.toggleTorch() }) {
                    Image(systemName: scannerService.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                        .font(.system(size: 24))
                        .padding()
                        .background(Circle().fill(Color.black.opacity(0.5)))
                        .foregroundColor(.white)
                }
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Scan Location QR")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showError) {
            Button("OK") { showError = false }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            scannerService.isScanningForLocations = true
            scannerService.startScanning()
            isScanning = true
            
            // Set up the handler for detected locations
            scannerService.onLocationDetected = { locationId in
                guard isScanning else { return }
                isScanning = false // Prevent multiple scans
                
                // Stop scanning immediately to prevent duplicate callbacks
                scannerService.stopScanning()
                
                // Find the location from the ID
                if let location = locationManager.getLocation(by: locationId) {
                    self.scannedLocation = location
                    self.showingLocationDetail = true
                    
                    // Navigate to the location and dismiss this view
                    DispatchQueue.main.async {
                        dismiss()
                        // Small delay to ensure dismiss completes first
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            // Send the navigation directly to the path
                            navigationCoordinator.path.append(NavigationDestination.scannedLocation(location))
                        }
                    }
                } else {
                    // Location not found
                    isScanning = true // Allow scanning again after error
                    errorMessage = "Location not found in your inventory"
                    showError = true
                    // Resume scanning after error
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        scannerService.startScanning()
                    }
                }
            }
        }
        .onDisappear {
            scannerService.stopScanning()
        }
    }
} 