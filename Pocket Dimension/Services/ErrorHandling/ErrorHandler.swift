import Foundation
import Combine

/// Centralized error handling service
@MainActor
public class ErrorHandler: ObservableObject {
    public static let shared = ErrorHandler()
    
    // Published properties for UI binding
    @Published public var currentError: AppError?
    @Published public var isShowingError = false
    @Published public var errorQueue: [AppError] = []
    @Published public var isRetrying = false
    
    // Error statistics
    @Published public var errorCount = 0
    @Published public var lastErrorTime: Date?
    
    // Configuration
    public var maxRetryAttempts = 3
    public var retryDelay: TimeInterval = 2.0
    public var logErrorsToConsole = true
    public var showAllErrors = true // Set to false to only show critical errors
    
    // Private properties
    private var retryAttempts: [String: Int] = [:]
    private var retryTimers: [String: Timer] = [:]
    private var errorHistory: [ErrorLogEntry] = []
    
    private init() {
        print("🟢 ErrorHandler: Initialized")
    }
    
    deinit {
        print("🔴 ErrorHandler: Deallocating")
        retryTimers.values.forEach { $0.invalidate() }
    }
    
    // MARK: - Public API
    
    /// Handle an error with automatic retry logic
    public func handle(
        _ error: Error,
        operation: (() async throws -> Void)? = nil,
        context: String = "",
        showToUser: Bool = true
    ) {
        let appError = AppError.from(error)
        handle(appError, operation: operation, context: context, showToUser: showToUser)
    }
    
    /// Handle an AppError with automatic retry logic
    public func handle(
        _ error: AppError,
        operation: (() async throws -> Void)? = nil,
        context: String = "",
        showToUser: Bool = true
    ) {
        // Log the error
        logError(error, context: context)
        
        // Update statistics
        errorCount += 1
        lastErrorTime = Date()
        
        // Determine if we should show this error to the user
        let shouldShow = showToUser && (showAllErrors || error.isCritical || error.requiresUserAction)
        
        if shouldShow {
            presentError(error)
        }
        
        // Handle retries if applicable
        if let operation = operation, error.isRetryable {
            scheduleRetry(for: error, operation: operation, context: context)
        }
    }
    
    /// Manually retry the last operation
    public func retryLastOperation() async {
        guard let error = currentError else { return }
        
        isRetrying = true
        defer { isRetrying = false }
        
        // Implement retry logic here based on the error type
        // This is a placeholder - specific operations would need to be passed in
        print("🔄 Retrying operation for error: \(error.id)")
        
        // For demo purposes, clear the current error
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        dismissCurrentError()
    }
    
    /// Dismiss the current error
    public func dismissCurrentError() {
        currentError = nil
        isShowingError = false
        
        // Show next error in queue if any
        if !errorQueue.isEmpty {
            let nextError = errorQueue.removeFirst()
            presentError(nextError)
        }
    }
    
    /// Clear all errors and reset state
    public func clearAllErrors() {
        currentError = nil
        isShowingError = false
        errorQueue.removeAll()
        retryAttempts.removeAll()
        retryTimers.values.forEach { $0.invalidate() }
        retryTimers.removeAll()
    }
    
    /// Get error history for debugging
    public func getErrorHistory() -> [ErrorLogEntry] {
        return errorHistory
    }
    
    /// Clear error history
    public func clearErrorHistory() {
        errorHistory.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func presentError(_ error: AppError) {
        if currentError == nil {
            // Show immediately
            currentError = error
            isShowingError = true
        } else {
            // Queue for later
            errorQueue.append(error)
        }
    }
    
    private func scheduleRetry(
        for error: AppError,
        operation: @escaping () async throws -> Void,
        context: String
    ) {
        let errorKey = "\(error.id)_\(context)"
        let currentAttempts = retryAttempts[errorKey] ?? 0
        
        guard currentAttempts < maxRetryAttempts else {
            print("❌ Max retry attempts reached for error: \(error.id)")
            return
        }
        
        let delay = retryDelay * pow(2.0, Double(currentAttempts)) // Exponential backoff
        
        print("⏳ Scheduling retry attempt \(currentAttempts + 1)/\(maxRetryAttempts) for error: \(error.id) in \(delay)s")
        
        retryTimers[errorKey] = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.performRetry(
                    for: error,
                    operation: operation,
                    context: context,
                    attempt: currentAttempts + 1
                )
            }
        }
    }
    
    private func performRetry(
        for error: AppError,
        operation: @escaping () async throws -> Void,
        context: String,
        attempt: Int
    ) async {
        let errorKey = "\(error.id)_\(context)"
        retryAttempts[errorKey] = attempt
        
        do {
            print("🔄 Retry attempt \(attempt) for error: \(error.id)")
            isRetrying = true
            try await operation()
            
            // Success - clear retry state
            retryAttempts.removeValue(forKey: errorKey)
            retryTimers.removeValue(forKey: errorKey)
            isRetrying = false
            
            // If this was the current error, dismiss it
            if currentError?.id == error.id {
                dismissCurrentError()
            }
            
            print("✅ Retry successful for error: \(error.id)")
            
        } catch {
            isRetrying = false
            let newError = AppError.from(error)
            
            // Check if we should retry again
            if attempt < maxRetryAttempts && newError.isRetryable {
                scheduleRetry(for: newError, operation: operation, context: context)
            } else {
                // Max retries reached or error not retryable
                print("❌ Retry failed permanently for error: \(newError.id)")
                handle(newError, context: "\(context)_retry_failed", showToUser: true)
            }
        }
    }
    
    private func logError(_ error: AppError, context: String) {
        let logEntry = ErrorLogEntry(
            error: error,
            context: context,
            timestamp: Date()
        )
        
        errorHistory.append(logEntry)
        
        // Keep only last 100 entries
        if errorHistory.count > 100 {
            errorHistory.removeFirst()
        }
        
        if logErrorsToConsole {
            let severity = error.severity
            let icon = severityIcon(for: severity)
            print("\(icon) ERROR [\(severity)] \(error.id): \(error.localizedDescription)")
            
            if !context.isEmpty {
                print("  Context: \(context)")
            }
            
            print("  Retryable: \(error.isRetryable)")
            print("  User Action Required: \(error.requiresUserAction)")
            print("  Critical: \(error.isCritical)")
        }
    }
    
    private func severityIcon(for severity: ErrorSeverity) -> String {
        switch severity {
        case .low: return "ℹ️"
        case .medium: return "⚠️"
        case .high: return "⛔"
        case .critical: return "🚨"
        }
    }
    
    // MARK: - Recovery Actions
    
    /// Execute a recovery action
    public func executeRecoveryAction(_ action: ErrorRecoveryAction) async {
        switch action {
        case .retry:
            await retryLastOperation()
            
        case .wait:
            // Show waiting state for rate limit
            isRetrying = true
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            isRetrying = false
            await retryLastOperation()
            
        case .signIn:
            // Navigate to sign in - would need to be coordinated with navigation
            print("🔐 User needs to sign in")
            
        case .checkConnection:
            // Provide network troubleshooting guidance
            print("🌐 User should check network connection")
            
        case .freeSpace:
            // Navigate to storage management
            print("💾 User needs to free up storage space")
            
        case .restoreBackup:
            // Navigate to backup restoration
            print("⏮️ User needs to restore from backup")
            
        case .resolveConflicts:
            // Navigate to conflict resolution
            print("⚡ User needs to resolve sync conflicts")
            
        case .restartApp:
            // Request app restart
            print("🔄 App restart required")
            
        case .upgradeStorage:
            // Navigate to storage upgrade
            print("⬆️ User needs to upgrade storage")
            
        case .continueOffline:
            // Enable offline mode
            print("✈️ Continuing in offline mode")
            dismissCurrentError()
            
        case .contactSupport:
            // Open support contact method
            print("📞 User should contact support")
        }
    }
}

// MARK: - Supporting Types

public struct ErrorLogEntry: Identifiable {
    public let id = UUID()
    public let error: AppError
    public let context: String
    public let timestamp: Date
    
    public var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
}

// MARK: - Convenience Extensions

extension ErrorHandler {
    /// Quick error handling for database operations
    public func handleDatabaseError(_ error: DatabaseManager.DatabaseError, context: String = "") {
        handle(AppError.from(error), context: context)
    }
    
    /// Quick error handling for network operations
    public func handleNetworkError(_ error: Error, context: String = "") {
        handle(AppError.from(error), context: context)
    }
    
    /// Handle validation errors
    public func handleValidationError(field: String, reason: String) {
        handle(AppError.invalidInput(field: field, reason: reason))
    }
    
    /// Handle duplicate entry errors
    public func handleDuplicateError(item: String) {
        handle(AppError.duplicateEntry(item))
    }
} 