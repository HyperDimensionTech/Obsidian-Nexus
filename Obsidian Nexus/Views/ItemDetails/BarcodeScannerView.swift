import SwiftUI

struct BarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = BarcodeScannerViewModel()
    let onScan: (String) -> Void
    
    var body: some View {
        ZStack {
            // Camera Preview
            if let session = viewModel.captureSession {
                CameraPreview(session: session)
                    .ignoresSafeArea()
            }
            
            // Scanning Frame
            VStack {
                // Top Bar
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .padding()
                    
                    Spacer()
                }
                
                Spacer()
                
                // Scan Frame
                Rectangle()
                    .strokeBorder(.white, lineWidth: 2)
                    .frame(width: 250, height: 150)
                
                Spacer()
                
                // Status Area
                VStack(spacing: 20) {
                    if let error = viewModel.error {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                    }
                    if let code = viewModel.scannedCode {
                        Text("Scanned: \(code)")
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                    }
                    
                    Text("Position barcode within frame")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.vertical)
                }
                .padding()
            }
        }
        .onAppear {
            viewModel.startScanning()
        }
        .onDisappear {
            viewModel.stopScanning()
        }
        .onChange(of: viewModel.scannedCode) { oldCode, newCode in
            if let code = newCode {
                onScan(code)
            }
        }
    }
} 