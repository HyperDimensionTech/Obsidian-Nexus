import SwiftUI
import UIKit
import Photos
import Combine

// Helper class to handle image saving callbacks
class ImageSaver: NSObject, ObservableObject {
    var onSuccess: (() -> Void)?
    var onError: ((Error) -> Void)?
    
    func saveImage(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(
            image,
            self,
            #selector(ImageSaver.image(_:didFinishSavingWithError:contextInfo:)),
            nil
        )
    }
    
    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            onError?(error)
        } else {
            onSuccess?()
        }
    }
}

struct LocationQRCodeView: View {
    let location: StorageLocation
    @State private var qrCodeImage: UIImage?
    @State private var shareUrl: URL?
    @State private var showingShareSheet = false
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @Environment(\.dismiss) private var dismiss
    
    // Image saver instance
    @StateObject private var imageSaver = ImageSaver()
    
    private let qrCodeService = QRCodeService.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Text("QR Code for \(location.name)")
                .font(.headline)
            
            if let qrCodeImage = qrCodeImage {
                Image(uiImage: qrCodeImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 250, height: 250)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                    .shadow(radius: 5)
                
                Text("Scan this code to access items in this location")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                HStack(spacing: 20) {
                    Button(action: {
                        if let url = URL(string: "pocketdimension://location/\(location.id.uuidString)") {
                            shareUrl = url
                            showingShareSheet = true
                        }
                    }) {
                        VStack {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 22))
                            Text("Share Link")
                                .font(.caption)
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    
                    Button(action: {
                        saveImageToPhotos(qrCodeImage)
                    }) {
                        VStack {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 22))
                            Text("Save to Photos")
                                .font(.caption)
                        }
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                
                Button(action: {
                    // Print QR code
                    printQRCode(qrCodeImage)
                }) {
                    VStack {
                        Image(systemName: "printer")
                            .font(.system(size: 22))
                        Text("Print QR Code")
                            .font(.caption)
                    }
                    .padding()
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.top, 10)
                }
            } else {
                ProgressView()
                    .padding()
                Text("Generating QR Code...")
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Location QR Code")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Generate QR code when view appears
            generateQRCode()
            
            // Set up image saver callbacks
            imageSaver.onSuccess = {
                showAlert(title: "Saved", message: "QR Code has been saved to your photos.")
            }
            imageSaver.onError = { error in
                showAlert(title: "Save error", message: error.localizedDescription)
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = shareUrl {
                ShareSheet(items: [url])
            } else if let image = qrCodeImage {
                // Share the image directly
                ShareSheet(items: [image])
            }
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func generateQRCode() {
        // Generate QR code with a larger size for better quality
        qrCodeImage = qrCodeService.generateQRCode(for: location.id, size: 1000)
        
        if qrCodeImage == nil {
            showAlert(title: "Error", message: "Failed to generate QR code")
        }
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
    
    private func saveImageToPhotos(_ image: UIImage) {
        imageSaver.saveImage(image)
    }
    
    private func printQRCode(_ image: UIImage) {
        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = "Location QR Code: \(location.name)"
        
        printController.printInfo = printInfo
        printController.printingItem = image
        
        printController.present(animated: true) { (_, completed, error) in
            if let error = error {
                showAlert(title: "Print Error", message: error.localizedDescription)
            }
        }
    }
}

// ShareSheet for sharing the QR code
struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
} 