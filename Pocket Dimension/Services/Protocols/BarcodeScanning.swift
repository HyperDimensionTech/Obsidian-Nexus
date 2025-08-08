import Foundation

public protocol BarcodeScanning {
    var scannedCode: String? { get }
    var isAuthorized: Bool { get }
    var error: String? { get }
    func start()
    func stop()
}


