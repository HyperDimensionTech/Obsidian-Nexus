import Foundation

/// Centralized error type for the entire application
public enum AppError: Error, LocalizedError, Identifiable {
    // Database errors
    case databaseConnection
    case databaseQuery(String)
    case databaseConstraint(String)
    case databaseMigration(String)
    case dataCorruption
    
    // Network errors
    case networkUnavailable
    case networkTimeout
    case serverError(Int, String)
    case invalidResponse
    case apiRateLimit
    
    // Authentication errors
    case authenticationFailed
    case authenticationRequired
    case sessionExpired
    case permissionDenied
    
    // Validation errors
    case invalidInput(field: String, reason: String)
    case duplicateEntry(String)
    case requiredFieldMissing(String)
    case invalidFormat(String)
    
    // Business logic errors
    case itemNotFound(String)
    case locationNotFound(String)
    case operationNotAllowed(String)
    case insufficientData
    
    // File system errors
    case fileNotFound(String)
    case fileAccessDenied
    case diskSpaceFull
    case fileCorrupted(String)
    
    // Sync errors
    case syncConflict
    case syncFailed(String)
    case cloudStorageQuotaExceeded
    case deviceOffline
    
    // Unknown errors
    case unknown(Error)
    
    // MARK: - Identifiable
    public var id: String {
        switch self {
        case .databaseConnection: return "db_connection"
        case .databaseQuery: return "db_query"
        case .databaseConstraint: return "db_constraint"
        case .databaseMigration: return "db_migration"
        case .dataCorruption: return "data_corruption"
        case .networkUnavailable: return "network_unavailable"
        case .networkTimeout: return "network_timeout"
        case .serverError: return "server_error"
        case .invalidResponse: return "invalid_response"
        case .apiRateLimit: return "api_rate_limit"
        case .authenticationFailed: return "auth_failed"
        case .authenticationRequired: return "auth_required"
        case .sessionExpired: return "session_expired"
        case .permissionDenied: return "permission_denied"
        case .invalidInput: return "invalid_input"
        case .duplicateEntry: return "duplicate_entry"
        case .requiredFieldMissing: return "required_field_missing"
        case .invalidFormat: return "invalid_format"
        case .itemNotFound: return "item_not_found"
        case .locationNotFound: return "location_not_found"
        case .operationNotAllowed: return "operation_not_allowed"
        case .insufficientData: return "insufficient_data"
        case .fileNotFound: return "file_not_found"
        case .fileAccessDenied: return "file_access_denied"
        case .diskSpaceFull: return "disk_space_full"
        case .fileCorrupted: return "file_corrupted"
        case .syncConflict: return "sync_conflict"
        case .syncFailed: return "sync_failed"
        case .cloudStorageQuotaExceeded: return "cloud_quota_exceeded"
        case .deviceOffline: return "device_offline"
        case .unknown: return "unknown"
        }
    }
    
    // MARK: - LocalizedError
    public var errorDescription: String? {
        switch self {
        case .databaseConnection:
            return "Unable to connect to the database. Please restart the app."
        case .databaseQuery(let message):
            return "Database error: \(message)"
        case .databaseConstraint(let constraint):
            return constraint.isEmpty ? "Data validation failed" : constraint
        case .databaseMigration(let message):
            return "Database update failed: \(message)"
        case .dataCorruption:
            return "Data corruption detected. Please restore from backup."
            
        case .networkUnavailable:
            return "No internet connection. Please check your network settings."
        case .networkTimeout:
            return "Request timed out. Please try again."
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .invalidResponse:
            return "Invalid response from server. Please try again."
        case .apiRateLimit:
            return "Too many requests. Please wait a moment and try again."
            
        case .authenticationFailed:
            return "Invalid credentials. Please check your login information."
        case .authenticationRequired:
            return "Please sign in to continue."
        case .sessionExpired:
            return "Your session has expired. Please sign in again."
        case .permissionDenied:
            return "You don't have permission to perform this action."
            
        case .invalidInput(let field, let reason):
            return "Invalid \(field): \(reason)"
        case .duplicateEntry(let item):
            return "\(item) already exists in your collection."
        case .requiredFieldMissing(let field):
            return "\(field) is required."
        case .invalidFormat(let field):
            return "Invalid format for \(field)."
            
        case .itemNotFound(let item):
            return "\(item) not found."
        case .locationNotFound(let location):
            return "Location '\(location)' not found."
        case .operationNotAllowed(let reason):
            return "Operation not allowed: \(reason)"
        case .insufficientData:
            return "Insufficient data to complete the operation."
            
        case .fileNotFound(let filename):
            return "File '\(filename)' not found."
        case .fileAccessDenied:
            return "Access denied. Please check file permissions."
        case .diskSpaceFull:
            return "Not enough storage space. Please free up space and try again."
        case .fileCorrupted(let filename):
            return "File '\(filename)' is corrupted."
            
        case .syncConflict:
            return "Sync conflict detected. Please resolve conflicts manually."
        case .syncFailed(let reason):
            return "Sync failed: \(reason)"
        case .cloudStorageQuotaExceeded:
            return "Cloud storage quota exceeded. Please upgrade your plan."
        case .deviceOffline:
            return "Device is offline. Changes will sync when connected."
            
        case .unknown(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Recovery Information
    
    /// Indicates if this error can be retried
    public var isRetryable: Bool {
        switch self {
        case .networkTimeout, .networkUnavailable, .serverError, .invalidResponse, .syncFailed, .deviceOffline:
            return true
        case .apiRateLimit:
            return true
        case .databaseConnection:
            return true
        default:
            return false
        }
    }
    
    /// Indicates if this error requires user action
    public var requiresUserAction: Bool {
        switch self {
        case .authenticationRequired, .sessionExpired, .permissionDenied:
            return true
        case .invalidInput, .requiredFieldMissing, .invalidFormat:
            return true
        case .diskSpaceFull, .cloudStorageQuotaExceeded:
            return true
        case .dataCorruption, .syncConflict:
            return true
        default:
            return false
        }
    }
    
    /// Indicates if this error is critical and requires immediate attention
    public var isCritical: Bool {
        switch self {
        case .dataCorruption, .databaseMigration, .fileCorrupted:
            return true
        case .diskSpaceFull:
            return !isRetryable
        default:
            return false
        }
    }
    
    /// Severity level for logging and UI treatment
    public var severity: ErrorSeverity {
        if isCritical {
            return .critical
        } else if requiresUserAction {
            return .high
        } else if isRetryable {
            return .medium
        } else {
            return .low
        }
    }
    
    /// Suggested recovery actions for the user
    public var recoveryActions: [ErrorRecoveryAction] {
        switch self {
        case .networkUnavailable, .networkTimeout:
            return [.retry, .checkConnection]
        case .serverError, .invalidResponse:
            return [.retry, .contactSupport]
        case .apiRateLimit:
            return [.wait, .retry]
        case .authenticationRequired, .sessionExpired:
            return [.signIn]
        case .permissionDenied:
            return [.contactSupport]
        case .diskSpaceFull:
            return [.freeSpace, .contactSupport]
        case .dataCorruption:
            return [.restoreBackup, .contactSupport]
        case .syncConflict:
            return [.resolveConflicts, .retry]
        case .databaseConnection:
            return [.restartApp, .contactSupport]
        case .cloudStorageQuotaExceeded:
            return [.upgradeStorage, .contactSupport]
        case .deviceOffline:
            return [.checkConnection, .continueOffline]
        default:
            return [.retry, .contactSupport]
        }
    }
}

// MARK: - Supporting Types

public enum ErrorSeverity {
    case low, medium, high, critical
    
    public var color: String {
        switch self {
        case .low: return "blue"
        case .medium: return "orange"
        case .high: return "red"
        case .critical: return "purple"
        }
    }
}

public enum ErrorRecoveryAction {
    case retry
    case wait
    case signIn
    case checkConnection
    case freeSpace
    case restoreBackup
    case resolveConflicts
    case restartApp
    case upgradeStorage
    case continueOffline
    case contactSupport
    
    public var title: String {
        switch self {
        case .retry: return "Try Again"
        case .wait: return "Wait"
        case .signIn: return "Sign In"
        case .checkConnection: return "Check Connection"
        case .freeSpace: return "Free Up Space"
        case .restoreBackup: return "Restore Backup"
        case .resolveConflicts: return "Resolve Conflicts"
        case .restartApp: return "Restart App"
        case .upgradeStorage: return "Upgrade Storage"
        case .continueOffline: return "Continue Offline"
        case .contactSupport: return "Contact Support"
        }
    }
    
    public var systemImage: String {
        switch self {
        case .retry: return "arrow.clockwise"
        case .wait: return "clock"
        case .signIn: return "person.circle"
        case .checkConnection: return "wifi"
        case .freeSpace: return "trash"
        case .restoreBackup: return "arrow.clockwise.icloud"
        case .resolveConflicts: return "exclamationmark.triangle"
        case .restartApp: return "arrow.triangle.2.circlepath"
        case .upgradeStorage: return "icloud.and.arrow.up"
        case .continueOffline: return "airplane"
        case .contactSupport: return "questionmark.circle"
        }
    }
}

// MARK: - Error Conversion Extensions

extension AppError {
    /// Convert from DatabaseManager.DatabaseError
    public static func from(_ error: DatabaseManager.DatabaseError) -> AppError {
        switch error {
        case .connectionFailed:
            return .databaseConnection
        case .queryFailed(let message):
            return .databaseQuery(message)
        case .constraintViolation(let constraint):
            return .databaseConstraint(constraint)
        case .invalidData:
            return .dataCorruption
        case .notFound:
            return .itemNotFound("Item")
        case .insertFailed, .updateFailed, .deleteFailed:
            return .databaseQuery("Database operation failed")
        case .transactionFailed(let message):
            return .databaseQuery(message)
        case .deadlock:
            return .databaseQuery("Database deadlock")
        case .diskFull:
            return .diskSpaceFull
        case .prepareFailed(let message):
            return .databaseQuery(message)
        case .notImplemented:
            return .operationNotAllowed("Feature not implemented")
        }
    }
    
    /// Convert from any Error
    public static func from(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        } else if let dbError = error as? DatabaseManager.DatabaseError {
            return .from(dbError)
        } else if error is URLError {
            let urlError = error as! URLError
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkUnavailable
            case .timedOut:
                return .networkTimeout
            case .cannotFindHost, .cannotConnectToHost:
                return .serverError(0, "Cannot connect to server")
            default:
                return .unknown(error)
            }
        } else {
            return .unknown(error)
        }
    }
} 
