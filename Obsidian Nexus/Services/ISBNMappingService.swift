import Foundation
import SwiftUI

class ISBNMappingService: ObservableObject {
    @Published var mappings: [ISBNMapping] = []
    
    private let userDefaults = UserDefaults.standard
    private let mappingsKey = "isbnMappings"
    private let repository: ISBNMappingRepository
    private let migratedKey = "isbnMappingsMigrated"
    
    init(storage: StorageManager = .shared) {
        self.repository = storage.getISBNMappingRepository()
        
        // Check if we need to migrate from UserDefaults
        if !UserDefaults.standard.bool(forKey: migratedKey) {
            // First load data from UserDefaults
            loadMappingsFromUserDefaults()
            
            // Then migrate to database
            migrateToDatabase()
            
            // Mark as migrated
            UserDefaults.standard.set(true, forKey: migratedKey)
        } else {
            // Load from database
            loadMappingsFromDatabase()
        }
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
        do {
            // First save to database
            for mapping in mappings {
                try repository.save(mapping)
            }
            
            // Also keep UserDefaults in sync until fully migrated everywhere
            if let encoded = try? JSONEncoder().encode(mappings) {
                userDefaults.set(encoded, forKey: mappingsKey)
            }
            
            objectWillChange.send()
        } catch {
            print("Error saving ISBN mappings: \(error.localizedDescription)")
        }
    }
    
    private func loadMappingsFromDatabase() {
        do {
            mappings = try repository.fetchAll()
        } catch {
            print("Error loading ISBN mappings from database: \(error.localizedDescription)")
            // Fallback to UserDefaults if database read fails
            loadMappingsFromUserDefaults()
        }
    }
    
    private func loadMappingsFromUserDefaults() {
        if let savedMappings = userDefaults.data(forKey: mappingsKey) {
            if let decodedMappings = try? JSONDecoder().decode([ISBNMapping].self, from: savedMappings) {
                mappings = decodedMappings
            }
        }
    }
    
    private func migrateToDatabase() {
        do {
            // Clear existing database records first
            try repository.deleteAll()
            
            // Save all mappings from UserDefaults to database
            for mapping in mappings {
                try repository.save(mapping)
            }
            
            print("Successfully migrated \(mappings.count) ISBN mappings to database")
        } catch {
            print("Error migrating ISBN mappings to database: \(error.localizedDescription)")
        }
    }
} 