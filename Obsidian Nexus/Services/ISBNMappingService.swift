import Foundation
import SwiftUI

class ISBNMappingService: ObservableObject {
    @Published var mappings: [ISBNMapping] = []
    
    private let userDefaults = UserDefaults.standard
    private let mappingsKey = "isbnMappings"
    
    init() {
        loadMappings()
    }
    
    // MARK: - Public Methods
    
    /// Check if a mapping exists for the given ISBN
    func getMappingForISBN(_ isbn: String) -> ISBNMapping? {
        return mappings.first { $0.incorrectISBN == isbn }
    }
    
    /// Add a new mapping - supports both property name formats
    func addMapping(incorrectISBN: String, googleBooksId: String, title: String, isReprint: Bool = true) {
        let newMapping = ISBNMapping(
            incorrectISBN: incorrectISBN,
            correctGoogleBooksID: googleBooksId,
            title: title,
            isReprint: isReprint
        )
        
        // Check if mapping already exists
        if !mappings.contains(where: { $0.incorrectISBN == incorrectISBN }) {
            mappings.append(newMapping)
            saveMappings()
        }
    }
    
    /// Remove a mapping
    func removeMapping(for isbn: String) {
        mappings.removeAll(where: { $0.incorrectISBN == isbn })
        saveMappings()
    }
    
    /// Clear all mappings
    func clearAllMappings() {
        mappings.removeAll()
        saveMappings()
    }
    
    func getGoogleBooksId(for isbn: String) -> String? {
        return mappings.first(where: { $0.incorrectISBN == isbn })?.correctGoogleBooksID
    }
    
    // MARK: - Private Methods
    
    private func saveMappings() {
        if let encoded = try? JSONEncoder().encode(mappings) {
            userDefaults.set(encoded, forKey: mappingsKey)
        }
        objectWillChange.send()
    }
    
    private func loadMappings() {
        if let savedMappings = userDefaults.data(forKey: mappingsKey) {
            if let decodedMappings = try? JSONDecoder().decode([ISBNMapping].self, from: savedMappings) {
                mappings = decodedMappings
            }
        }
    }
} 