import SwiftUI

struct BarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = BarcodeScannerViewModel()
    let onScan: (String) -> Void
    @Namespace private var animation
    
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
                    
                    Spacer()
                    
                    // Enhanced Torch Toggle Button with haptic feedback
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            viewModel.toggleTorch()
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                        }
                    }) {
                        Image(systemName: viewModel.torchEnabled ? "flashlight.on.fill" : "flashlight.off.fill")
                            .font(.title2)
                            .foregroundColor(viewModel.torchEnabled ? .yellow : .white)
                            .padding()
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                viewModel.torchEnabled ? Color.yellow : Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                            )
                    }
                    // Move animations outside Button but remove onTapGesture
                    .scaleEffect(viewModel.torchEnabled ? 1.1 : 1.0)
                    .rotationEffect(.degrees(viewModel.torchEnabled ? 360 : 0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.torchEnabled)
                    .overlay(
                        viewModel.torchEnabled ? 
                        Circle()
                            .fill(Color.yellow.opacity(0.3))
                            .scaleEffect(1.5)
                            .blur(radius: 20)
                        : nil
                    )
                    .accessibilityLabel(viewModel.torchEnabled ? "Turn off flashlight" : "Turn on flashlight")
                }
                .padding()
                
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
            // Ensure torch is off when view disappears
            if viewModel.torchEnabled {
                viewModel.toggleTorch()
            }
            viewModel.stopScanning()
        }
        .onChange(of: viewModel.scannedCode) { oldCode, newCode in
            if let code = newCode {
                onScan(code)
            }
        }
    }
} 