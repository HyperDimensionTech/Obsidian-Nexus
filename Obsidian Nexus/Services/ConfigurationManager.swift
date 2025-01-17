import Foundation

enum ConfigurationError: LocalizedError {
    case missingConfigFile
    case missingKey(String)
    
    var errorDescription: String? {
        switch self {
        case .missingConfigFile:
            return "Config.plist file not found"
        case .missingKey(let key):
            return "Missing configuration key: \(key)"
        }
    }
}

class ConfigurationManager {
    static let shared = ConfigurationManager()
    
    private var configDictionary: [String: Any]?
    
    private init() {
        loadConfiguration()
    }
    
    private func loadConfiguration() {
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) as? [String: Any] {
            configDictionary = dict
        } else {
            print("⚠️ Warning: Config.plist not found. Using empty configuration.")
            configDictionary = [:]
        }
    }
    
    func string(for key: String) -> String? {
        return configDictionary?[key] as? String
    }
    
    func requireString(for key: String) throws -> String {
        guard let value = string(for: key) else {
            throw ConfigurationError.missingKey(key)
        }
        return value
    }
} 