import SwiftUI
import CoreImage.CIFilterBuiltins

/**
 Service for generating and parsing QR codes for locations in the app.
 
 This service provides functionality to:
 1. Generate QR codes that contain location identifiers
 2. Parse scanned QR codes to extract location identifiers
 
 The QR codes use a custom URL scheme (`pocketdimension://`) for deep linking
 to specific locations within the app.
 
 ## Usage
 
 ### Generating a QR code for a location
 
 ```swift
 // Get the shared instance
 let qrService = QRCodeService.shared
 
 // Generate a QR code image for a location
 if let qrImage = qrService.generateQRCode(for: myLocation.id) {
     // Use the QR code image in your view
     Image(uiImage: qrImage)
         .interpolation(.none)
         .resizable()
         .scaledToFit()
 }
 ```
 
 ### Parsing a scanned QR code
 
 ```swift
 // When a QR code is scanned and returns a string
 func handleScannedCode(_ code: String) {
     if let locationId = QRCodeService.shared.parseLocationQRCode(from: code) {
         // Location QR code detected, load the location
         if let location = locationManager.location(withId: locationId) {
             navigationCoordinator.navigate(to: .scannedLocation(location))
         }
     } else {
         // Not a valid location QR code
         showInvalidCodeAlert = true
     }
 }
 ```
 */
class QRCodeService {
    /// Shared singleton instance
    static let shared = QRCodeService()
    
    /// Core Image context for rendering
    private let context = CIContext()
    
    /// Filter used to generate QR codes
    private let filter = CIFilter.qrCodeGenerator()
    
    /// The URL scheme to use for deep linking
    private let urlScheme = "pocketdimension"
    
    /// Private initializer to enforce singleton pattern
    private init() {}
    
    /**
     Generates a QR code image for a specific location.
     
     The generated QR code contains a URL in the format 
     `pocketdimension://location/{locationId}` which can be scanned
     to navigate directly to the location in the app.
     
     - Parameters:
        - locationId: The UUID of the location to encode in the QR code
        - size: The size of the generated QR code image in points (default: 200)
     
     - Returns: A UIImage containing the QR code, or nil if generation fails
     */
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
    
    /**
     Parses a scanned QR code string to extract a location ID.
     
     This method checks if the scanned string matches the expected format of
     `pocketdimension://location/{UUID}` and extracts the UUID if valid.
     
     - Parameter string: The string content of the scanned QR code
     
     - Returns: A UUID if the string contains a valid location link, nil otherwise
     */
    func parseLocationQRCode(from string: String) -> UUID? {
        // Expected format: pocketdimension://location/UUID-STRING
        guard string.hasPrefix("\(urlScheme)://location/") else { return nil }
        
        let components = string.components(separatedBy: "/")
        guard components.count > 2 else { return nil }
        
        let uuidString = components.last!
        return UUID(uuidString: uuidString)
    }
} 