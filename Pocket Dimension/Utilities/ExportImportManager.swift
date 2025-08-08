import Foundation
import SwiftUI
import UniformTypeIdentifiers

/**
 Manages the export and import of inventory data and QR code image files.
 
 This class provides functionality for exporting inventory data to JSON files,
 importing data from JSON files, and exporting generated QR codes as image files.
 
 ## Features
 
 - Export inventory data to JSON files
 - Import inventory data from JSON files
 - Export QR code images to the photo library or as files
 - Generate file names based on content and timestamps
 
 ## Usage Examples
 
 ### Exporting Inventory
 
 ```swift
 // Create a FileDocument for export
 let document = manager.createInventoryExportDocument(items: myItems, locations: myLocations)
 
 // Present the export sheet
 isExporting = true
 ```
 
 ### Importing Inventory
 
 ```swift
 // Start the import process
 isImporting = true
 
 // Handle the imported file in your SwiftUI view
 .fileImporter(
     isPresented: $isImporting,
     allowedContentTypes: [.json],
     onCompletion: { result in
         switch result {
         case .success(let url):
             guard url.startAccessingSecurityScopedResource() else { return }
             defer { url.stopAccessingSecurityScopedResource() }
             
             if let importedData = manager.importInventoryData(from: url) {
                 // Process the imported data
                 processImportedData(importedData)
             }
         case .failure(let error):
             print("Import failed: \(error.localizedDescription)")
         }
     }
 )
 ```
 
 ### Exporting QR Codes
 
 ```swift
 if let image = myQRCodeImage {
     let document = manager.createQRCodeExportDocument(
         image: image,
         title: "Location: My Bookshelf"
     )
     isExporting = true
 }
 ```
 */
class ExportImportManager: ObservableObject {
    // MARK: - Properties
    
    /// Singleton instance for app-wide access
    static let shared = ExportImportManager()
    
    /// Private initializer for singleton pattern
    private init() {}
    
    // MARK: - Inventory Export
    
    /**
     Creates a FileDocument containing inventory data in JSON format.
     
     - Parameters:
        - items: Array of inventory items to include in the export
        - locations: Array of storage locations to include in the export
     
     - Returns: A FileDocument ready for export via SwiftUI's fileExporter
     */
    func createInventoryExportDocument(items: [InventoryItem], locations: [StorageLocation]) -> InventoryExportDocument {
        let exportData = InventoryExportData(items: items, locations: locations)
        return InventoryExportDocument(exportData: exportData)
    }
    
    // MARK: - Inventory Import
    
    /**
     Imports inventory data from a JSON file at the specified URL.
     
     - Parameter url: URL pointing to the JSON file to import
     
     - Returns: InventoryExportData if successful, nil if import failed
     */
    func importInventoryData(from url: URL) -> InventoryExportData? {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode(InventoryExportData.self, from: data)
        } catch {
            print("Failed to import inventory data: \(error)")
            return nil
        }
    }
    
    // MARK: - QR Code Export
    
    /**
     Creates a FileDocument containing a QR code image.
     
     - Parameters:
        - image: The UIImage containing the QR code
        - title: Optional descriptive title to use in the filename
     
     - Returns: A FileDocument ready for export via SwiftUI's fileExporter
     */
    func createQRCodeExportDocument(image: UIImage, title: String? = nil) -> QRCodeExportDocument {
        return QRCodeExportDocument(image: image, title: title)
    }
    
    // MARK: - Helper Methods
    
    /**
     Generates a timestamped filename based on content and optional title.
     
     - Parameters:
        - prefix: Prefix for the filename
        - title: Optional descriptive title to include
        - fileExtension: File extension to use
     
     - Returns: A string with format "prefix_title_timestamp.extension"
     */
    func generateFilename(prefix: String, title: String? = nil, fileExtension: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = dateFormatter.string(from: Date())
        
        var filename = prefix
        
        if let title = title, !title.isEmpty {
            let sanitizedTitle = title
                .replacingOccurrences(of: " ", with: "_")
                .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-")))
                .joined()
                .prefix(32)
            
            filename += "_\(sanitizedTitle)"
        }
        
        filename += "_\(dateString).\(fileExtension)"
        return filename
    }
}

// MARK: - Export Data Structure

/**
 Data structure for exporting and importing inventory data.
 
 Contains arrays of inventory items and storage locations that can be serialized to JSON.
 */
struct InventoryExportData: Codable {
    /// Array of inventory items to export
    let items: [InventoryItem]
    
    /// Array of storage locations to export
    let locations: [StorageLocation]
    
    /**
     Initializes a new export data structure with items and locations.
     
     - Parameters:
        - items: Array of inventory items to include
        - locations: Array of storage locations to include
     */
    init(items: [InventoryItem], locations: [StorageLocation]) {
        self.items = items
        self.locations = locations
    }
}

// MARK: - Inventory Export Document

/**
 SwiftUI FileDocument for exporting inventory data.
 
 This document handles serializing inventory data to JSON format for export.
 */
struct InventoryExportDocument: FileDocument {
    /// Supported content types for this document
    static var readableContentTypes: [UTType] = [.json]
    
    /// The inventory data to export
    var exportData: InventoryExportData
    
    /// The JSON data representation of the inventory
    var jsonData: Data?
    
    /**
     Initializes a new export document with inventory data.
     
     - Parameter exportData: The inventory data to export
     */
    init(exportData: InventoryExportData) {
        self.exportData = exportData
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            self.jsonData = try encoder.encode(exportData)
        } catch {
            print("Failed to encode inventory data: \(error)")
            self.jsonData = nil
        }
    }
    
    /**
     Initializes a new document from file contents.
     
     Required by the FileDocument protocol but not used for export.
     
     - Parameters:
        - configuration: The file configuration
        - contentType: The content type of the file
     */
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        let decoder = JSONDecoder()
        self.exportData = try decoder.decode(InventoryExportData.self, from: data)
        self.jsonData = data
    }
    
    /**
     Writes the document contents to a file.
     
     - Parameter configuration: The file configuration for writing
     
     - Returns: A file wrapper containing the JSON data
     */
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let data = jsonData else {
            throw CocoaError(.fileWriteUnknown)
        }
        
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - QR Code Export Document

/**
 SwiftUI FileDocument for exporting QR code images.
 
 This document handles converting UIImage to PNG data for export.
 */
struct QRCodeExportDocument: FileDocument {
    /// Supported content types for this document
    static var readableContentTypes: [UTType] = [.png]
    
    /// The QR code image to export
    var image: UIImage
    
    /// Optional title for filename generation
    var title: String?
    
    /**
     Initializes a new export document with a QR code image.
     
     - Parameters:
        - image: The UIImage containing the QR code
        - title: Optional descriptive title to use in the filename
     */
    init(image: UIImage, title: String? = nil) {
        self.image = image
        self.title = title
    }
    
    /**
     Initializes a new document from file contents.
     
     Required by the FileDocument protocol but not used for QR export.
     
     - Parameters:
        - configuration: The file configuration
        - contentType: The content type of the file
     */
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let image = UIImage(data: data) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        self.image = image
        self.title = nil
    }
    
    /**
     Writes the document contents to a file.
     
     - Parameter configuration: The file configuration for writing
     
     - Returns: A file wrapper containing the PNG image data
     */
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let data = image.pngData() else {
            throw CocoaError(.fileWriteUnknown)
        }
        
        return FileWrapper(regularFileWithContents: data)
    }
} 