import Foundation

// MARK: - API Configuration Manager

/// Centralized configuration manager for API keys and settings
public class APIConfiguration: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = APIConfiguration()
    
    // MARK: - Configuration Properties
    
    /// Google Books API key
    public private(set) var googleBooksAPIKey: String?
    
    /// Firebase configuration
    public private(set) var firebaseProjectID: String?
    public private(set) var firebaseAPIKey: String?
    
    /// Supabase configuration
    public private(set) var supabaseURL: String?
    public private(set) var supabaseKey: String?
    
    /// Authentication service configuration
    public private(set) var authServiceBaseURL: String?
    
    /// iCloud configuration
    public private(set) var iCloudContainerIdentifier: String?
    
    /// API settings
    public private(set) var googleBooksMaxResults: Int = 40
    public private(set) var requestTimeout: TimeInterval = 30
    public private(set) var enableDebugLogging: Bool = false
    
    // MARK: - Configuration Status
    
    @Published public private(set) var isConfigurationLoaded = false
    @Published public private(set) var configurationError: String?
    
    // MARK: - Private Properties
    
    private var configurationDictionary: [String: Any] = [:]
    
    // MARK: - Initialization
    
    private init() {
        loadConfiguration()
    }
    
    // MARK: - Configuration Loading
    
    /// Load configuration from Config.plist
    private func loadConfiguration() {
        do {
            configurationDictionary = try loadConfigurationPlist()
            parseConfiguration()
            isConfigurationLoaded = true
            configurationError = nil
            
            if enableDebugLogging {
                print("🔧 APIConfiguration: Configuration loaded successfully")
                printConfigurationStatus()
            }
            
        } catch {
            let errorMessage = "Failed to load API configuration: \(error.localizedDescription)"
            configurationError = errorMessage
            isConfigurationLoaded = false
            
            print("❌ APIConfiguration Error: \(errorMessage)")
            print("💡 Make sure Config.plist exists and is properly formatted")
            print("💡 Copy Config.example.plist to Config.plist and add your API keys")
        }
    }
    
    /// Load the plist file and return its contents
    private func loadConfigurationPlist() throws -> [String: Any] {
        // Try to load Config.plist first
        if let configPath = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let configData = NSDictionary(contentsOfFile: configPath) as? [String: Any] {
            return configData
        }
        
        // Fallback to Config.example.plist for development
        if let examplePath = Bundle.main.path(forResource: "Config.example", ofType: "plist"),
           let exampleData = NSDictionary(contentsOfFile: examplePath) as? [String: Any] {
            print("⚠️ Using Config.example.plist - Please create Config.plist with real API keys")
            return exampleData
        }
        
        throw APIConfigurationError.configurationFileNotFound
    }
    
    /// Parse the loaded configuration dictionary
    private func parseConfiguration() {
        // Google Books API
        googleBooksAPIKey = configurationDictionary["GoogleBooksAPIKey"] as? String
        
        // Firebase
        firebaseProjectID = configurationDictionary["FirebaseProjectID"] as? String
        firebaseAPIKey = configurationDictionary["FirebaseAPIKey"] as? String
        
        // Supabase
        supabaseURL = configurationDictionary["SupabaseURL"] as? String
        supabaseKey = configurationDictionary["SupabaseKey"] as? String
        
        // Authentication Service
        authServiceBaseURL = configurationDictionary["AuthServiceBaseURL"] as? String
        
        // iCloud
        iCloudContainerIdentifier = configurationDictionary["iCloudContainerIdentifier"] as? String
        
        // API Configuration
        if let apiConfig = configurationDictionary["APIConfiguration"] as? [String: Any] {
            googleBooksMaxResults = apiConfig["GoogleBooksMaxResults"] as? Int ?? 40
            requestTimeout = TimeInterval(apiConfig["RequestTimeout"] as? Int ?? 30)
            enableDebugLogging = apiConfig["EnableDebugLogging"] as? Bool ?? false
        }
    }
    
    // MARK: - Public Methods
    
    /// Reload configuration (useful for testing or dynamic updates)
    public func reloadConfiguration() {
        loadConfiguration()
    }
    
    /// Check if Google Books API is configured
    public var isGoogleBooksConfigured: Bool {
        return googleBooksAPIKey != nil && 
               !googleBooksAPIKey!.isEmpty && 
               googleBooksAPIKey != "YOUR_GOOGLE_BOOKS_API_KEY_HERE"
    }
    
    /// Check if Firebase is configured
    public var isFirebaseConfigured: Bool {
        return firebaseProjectID != nil && firebaseAPIKey != nil &&
               !firebaseProjectID!.isEmpty && !firebaseAPIKey!.isEmpty &&
               firebaseProjectID != "your-firebase-project-id"
    }
    
    /// Check if Supabase is configured
    public var isSupabaseConfigured: Bool {
        return supabaseURL != nil && supabaseKey != nil &&
               !supabaseURL!.isEmpty && !supabaseKey!.isEmpty &&
               supabaseURL != "https://your-project.supabase.co"
    }
    
    /// Get configuration value for a specific key
    public func getValue(for key: String) -> Any? {
        return configurationDictionary[key]
    }
    
    // MARK: - Debug Methods
    
    /// Print configuration status (for debugging)
    private func printConfigurationStatus() {
        print("📊 API Configuration Status:")
        print("  • Google Books API: \(isGoogleBooksConfigured ? "✅ Configured" : "❌ Not configured")")
        print("  • Firebase: \(isFirebaseConfigured ? "✅ Configured" : "❌ Not configured")")
        print("  • Supabase: \(isSupabaseConfigured ? "✅ Configured" : "❌ Not configured")")
        print("  • Auth Service: \(authServiceBaseURL != nil ? "✅ Configured" : "❌ Not configured")")
        print("  • iCloud Container: \(iCloudContainerIdentifier != nil ? "✅ Configured" : "❌ Not configured")")
    }
    
    /// Generate configuration report for support/debugging
    public func generateConfigurationReport() -> String {
        var report = "API Configuration Report\n"
        report += "========================\n"
        report += "Configuration Loaded: \(isConfigurationLoaded)\n"
        report += "Google Books API: \(isGoogleBooksConfigured ? "Configured" : "Not configured")\n"
        report += "Firebase: \(isFirebaseConfigured ? "Configured" : "Not configured")\n"
        report += "Supabase: \(isSupabaseConfigured ? "Configured" : "Not configured")\n"
        
        if let error = configurationError {
            report += "Error: \(error)\n"
        }
        
        return report
    }
}

// MARK: - Configuration Errors

public enum APIConfigurationError: LocalizedError {
    case configurationFileNotFound
    case invalidConfigurationFormat
    case missingRequiredKey(String)
    
    public var errorDescription: String? {
        switch self {
        case .configurationFileNotFound:
            return "Configuration file (Config.plist) not found. Please create it from Config.example.plist"
        case .invalidConfigurationFormat:
            return "Configuration file format is invalid. Please check the plist structure"
        case .missingRequiredKey(let key):
            return "Required configuration key '\(key)' is missing"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .configurationFileNotFound:
            return "Copy Config.example.plist to Config.plist and add your API keys"
        case .invalidConfigurationFormat:
            return "Verify that Config.plist is a valid property list file"
        case .missingRequiredKey:
            return "Add the missing key to your Config.plist file"
        }
    }
}

// MARK: - Convenience Extensions

extension APIConfiguration {
    /// Get Google Books API key with validation
    public func getGoogleBooksAPIKey() throws -> String {
        guard let key = googleBooksAPIKey, !key.isEmpty, key != "YOUR_GOOGLE_BOOKS_API_KEY_HERE" else {
            throw APIConfigurationError.missingRequiredKey("GoogleBooksAPIKey")
        }
        return key
    }
    
    /// Get Firebase configuration with validation
    public func getFirebaseConfiguration() throws -> (projectID: String, apiKey: String) {
        guard let projectID = firebaseProjectID, !projectID.isEmpty, projectID != "your-firebase-project-id" else {
            throw APIConfigurationError.missingRequiredKey("FirebaseProjectID")
        }
        guard let apiKey = firebaseAPIKey, !apiKey.isEmpty, apiKey != "your-firebase-api-key" else {
            throw APIConfigurationError.missingRequiredKey("FirebaseAPIKey")
        }
        return (projectID: projectID, apiKey: apiKey)
    }
    
    /// Get Supabase configuration with validation
    public func getSupabaseConfiguration() throws -> (url: String, key: String) {
        guard let url = supabaseURL, !url.isEmpty, url != "https://your-project.supabase.co" else {
            throw APIConfigurationError.missingRequiredKey("SupabaseURL")
        }
        guard let key = supabaseKey, !key.isEmpty, key != "your-supabase-anon-key" else {
            throw APIConfigurationError.missingRequiredKey("SupabaseKey")
        }
        return (url: url, key: key)
    }
} 