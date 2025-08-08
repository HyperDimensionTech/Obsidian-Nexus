import Foundation
import UIKit

extension QRCodeService: QRCodeGenerating {
    func generateQRCode(for locationId: UUID, size: CGSize) -> UIImage? {
        return generateQRCode(for: locationId, size: max(size.width, size.height))
    }
}


