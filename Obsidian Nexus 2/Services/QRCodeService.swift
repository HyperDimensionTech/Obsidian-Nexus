import SwiftUI
import CoreImage.CIFilterBuiltins

class QRCodeService {
    static let shared = QRCodeService()
    
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()
    
    // The URL scheme to use for deep linking
    private let urlScheme = "pocketdimension"
    
    private init() {}
    
    // Generate QR code for a location
    func generateQRCode(for locationId: UUID, size: CGFloat = 200) -> UIImage? {
        let locationURL = "\(urlScheme)://location/\(locationId.uuidString)"
        
        // Create the QR code
        guard let data = locationURL.data(using: .utf8) else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel") // Medium error correction
        
        // Get the CIImage output and convert to UIImage
        guard let ciImage = filter.outputImage else { return nil }
        
        // Scale the image to the requested size
        let scale = size / ciImage.extent.width
        let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
    
    // Parse a scanned QR code to extract the location ID
    func parseLocationQRCode(from string: String) -> UUID? {
        // Expected format: pocketdimension://location/UUID-STRING
        guard string.hasPrefix("\(urlScheme)://location/") else { return nil }
        
        let components = string.components(separatedBy: "/")
        guard components.count > 2 else { return nil }
        
        let uuidString = components.last!
        return UUID(uuidString: uuidString)
    }
} 