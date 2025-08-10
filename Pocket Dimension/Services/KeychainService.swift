import Foundation
import Security

// MARK: - Keychain Service

public class KeychainService {
    
    // MARK: - Configuration
    
    private let service = "com.hyperdimension.Pocket-Dimension"
    private let sessionAccount = "auth_session"
    
    // MARK: - Public Methods
    
    /// Save authentication session to keychain
    public func saveSession(_ session: AuthSession) throws {
        let data = try JSONEncoder().encode(session)
        try saveData(data, account: sessionAccount)
    }
    
    /// Retrieve authentication session from keychain
    public func getSession() throws -> AuthSession {
        let data = try getData(account: sessionAccount)
        return try JSONDecoder().decode(AuthSession.self, from: data)
    }
    
    /// Clear authentication session from keychain
    public func clearSession() throws {
        try deleteData(account: sessionAccount)
    }
    
    // MARK: - Private Methods
    
    private func saveData(_ data: Data, account: String) throws {
        // First, try to update existing item
        let updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)
        
        if updateStatus == errSecSuccess {
            return // Successfully updated
        }
        
        // If update failed because item doesn't exist, create new item
        if updateStatus == errSecItemNotFound {
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            ]
            
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            
            if addStatus != errSecSuccess {
                throw KeychainError.saveFailed(addStatus)
            }
        } else {
            throw KeychainError.saveFailed(updateStatus)
        }
    }
    
    private func getData(account: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess {
            guard let data = result as? Data else {
                throw KeychainError.invalidData
            }
            return data
        } else if status == errSecItemNotFound {
            throw KeychainError.itemNotFound
        } else {
            throw KeychainError.loadFailed(status)
        }
    }
    
    private func deleteData(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.deleteFailed(status)
        }
    }
}

// MARK: - Keychain Errors

public enum KeychainError: Error, LocalizedError {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case deleteFailed(OSStatus)
    case itemNotFound
    case invalidData
    
    public var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save to keychain: \(status)"
        case .loadFailed(let status):
            return "Failed to load from keychain: \(status)"
        case .deleteFailed(let status):
            return "Failed to delete from keychain: \(status)"
        case .itemNotFound:
            return "Item not found in keychain"
        case .invalidData:
            return "Invalid data retrieved from keychain"
        }
    }
}

// MARK: - Keychain Helper Extensions

extension KeychainService {
    
    /// Save any Codable object to keychain
    public func save<T: Codable>(_ object: T, account: String) throws {
        let data = try JSONEncoder().encode(object)
        try saveData(data, account: account)
    }
    
    /// Load any Codable object from keychain
    public func load<T: Codable>(_ type: T.Type, account: String) throws -> T {
        let data = try getData(account: account)
        return try JSONDecoder().decode(type, from: data)
    }
    
    /// Delete any item from keychain
    public func delete(account: String) throws {
        try deleteData(account: account)
    }
    
    /// Check if an item exists in keychain
    public func exists(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
} 