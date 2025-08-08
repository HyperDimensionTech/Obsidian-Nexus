import Foundation
import UIKit

public protocol QRCodeGenerating {
    func generateQRCode(for locationId: UUID, size: CGSize) -> UIImage?
}


