import Foundation
import SwiftUI

class ISBNMappingService: ObservableObject {
    @Published var mappings: [ISBNMapping] = []
    
    private let repository: ISBNMappingRepository
    
    init(storage: StorageManager = .shared) {
        self.repository = storage.getISBNMappingRepository()
        loadMappingsFromDatabase()
        
        // Listen for data import notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDataImport),
            name: .dataImportCompleted,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleDataImport() {
        loadMappingsFromDatabase()
    }
    
    // MARK: - Public Methods
    
    /// Check if a mapping exists for the given ISBN
    func getMappingForISBN(_ isbn: String) -> ISBNMapping? {
        return mappings.first { $0.incorrectISBN == isbn }
    }
    
    /// Add a new mapping
    func addMapping(incorrectISBN: String, googleBooksId: String, title: String, isReprint: Bool = true) {
        let newMapping = ISBNMapping(
            incorrectISBN: incorrectISBN,
            correctGoogleBooksID: googleBooksId,
            title: title,
            isReprint: isReprint
        )
        
        // Check if mapping already exists
        if !mappings.contains(where: { $0.incorrectISBN == incorrectISBN }) {
            do {
                try repository.save(newMapping)
                mappings.append(newMapping)
                objectWillChange.send()
            } catch {
                print("Error saving mapping: \(error.localizedDescription)")
            }
        }
    }
    
    /// Remove a mapping
    func removeMapping(for isbn: String) {
        do {
            try repository.delete(isbn)
            mappings.removeAll(where: { $0.incorrectISBN == isbn })
            objectWillChange.send()
        } catch {
            print("Error removing mapping: \(error.localizedDescription)")
        }
    }
    
    /// Clear all mappings
    func clearAllMappings() {
        do {
            try repository.deleteAll()
            mappings.removeAll()
            objectWillChange.send()
        } catch {
            print("Error clearing all mappings: \(error.localizedDescription)")
        }
    }
    
    /// Remove a mapping by title substring (for maintenance)
    func removeMapping(titleContaining substring: String) {
        print("Removing ISBN mappings containing: \(substring)")
        
        // Find all mappings with titles containing the substring
        let matchingMappings = mappings.filter { 
            $0.title.lowercased().contains(substring.lowercased()) 
        }
        
        if matchingMappings.isEmpty {
            print("No mappings found with title containing: \(substring)")
            return
        }
        
        // Remove each matching mapping
        for mapping in matchingMappings {
            print("Removing mapping: \(mapping.incorrectISBN) -> \(mapping.title)")
            removeMapping(for: mapping.incorrectISBN)
        }
    }
    
    func getGoogleBooksId(for isbn: String) -> String? {
        return mappings.first(where: { $0.incorrectISBN == isbn })?.correctGoogleBooksID
    }
    
    // MARK: - Private Methods
    
    private func loadMappingsFromDatabase() {
        do {
            mappings = try repository.fetchAll()
            print("Successfully loaded \(mappings.count) ISBN mappings from database")
            objectWillChange.send()
        } catch {
            print("Error loading ISBN mappings from database: \(error.localizedDescription)")
            mappings = []
        }
    }
} 