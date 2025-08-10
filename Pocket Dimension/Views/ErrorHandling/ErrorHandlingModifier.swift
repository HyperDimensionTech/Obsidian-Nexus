import SwiftUI

// MARK: - Error Handling View Modifier

/// View modifier that adds error handling capabilities to any view
public struct ErrorHandlingModifier: ViewModifier {
    @StateObject private var errorHandler = ErrorHandler.shared
    
    let errorDisplayMode: ErrorDisplayMode
    let onRecoveryAction: ((ErrorRecoveryAction) async -> Void)?
    
    public init(
        errorDisplayMode: ErrorDisplayMode = .alert,
        onRecoveryAction: ((ErrorRecoveryAction) async -> Void)? = nil
    ) {
        self.errorDisplayMode = errorDisplayMode
        self.onRecoveryAction = onRecoveryAction
    }
    
    public func body(content: Content) -> some View {
        ZStack {
            content
            
            // Toast container for toast notifications
            if errorDisplayMode == .toast || errorDisplayMode == .both {
                VStack {
                    Spacer()
                    ToastContainer()
                }
                .allowsHitTesting(false)
            }
        }
        .alert(
            errorHandler.currentError?.errorDescription ?? "Error",
            isPresented: $errorHandler.isShowingError
        ) {
            Button("Dismiss", role: .cancel) {
                errorHandler.dismissCurrentError()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .errorOccurred)) { notification in
            if let error = notification.object as? AppError {
                handleError(error)
            }
        }
    }
    
    private func handleError(_ error: AppError) {
        switch errorDisplayMode {
        case .alert:
            errorHandler.handle(error, showToUser: true)
        case .toast:
            errorHandler.showToast(for: error)
        case .both:
            if error.isCritical || error.requiresUserAction {
                errorHandler.handle(error, showToUser: true)
            } else {
                errorHandler.showToast(for: error)
            }
        case .none:
            errorHandler.handle(error, showToUser: false)
        }
    }
    
    private func performRecoveryAction(_ action: ErrorRecoveryAction) async {
        if let customHandler = onRecoveryAction {
            await customHandler(action)
        } else {
            await errorHandler.executeRecoveryAction(action)
        }
    }
}

// MARK: - Error Display Mode

public enum ErrorDisplayMode {
    case alert      // Show errors as alerts
    case toast      // Show errors as toast notifications
    case both       // Critical errors as alerts, others as toasts
    case none       // Don't show errors to user (still logged)
}

// MARK: - View Extension

extension View {
    /// Add error handling to any view
    public func errorHandling(
        mode: ErrorDisplayMode = .alert,
        onRecoveryAction: ((ErrorRecoveryAction) async -> Void)? = nil
    ) -> some View {
        modifier(ErrorHandlingModifier(
            errorDisplayMode: mode,
            onRecoveryAction: onRecoveryAction
        ))
    }
    
    // Custom error handler functionality temporarily disabled due to compiler issues
    // You can use the global ErrorHandler.shared instead
    
    /// Add loading and error states
    public func loadingErrorState(
        isLoading: Bool,
        error: AppError? = nil,
        loadingMessage: String = "Loading...",
        onRetry: (() async -> Void)? = nil
    ) -> some View {
        return LoadingErrorView(
            isLoading: isLoading,
            error: error,
            loadingMessage: loadingMessage,
            onRetry: onRetry
        ) {
            self
        }
    }
    
    /// Add async operation state handling
    public func asyncOperationState(
        _ state: AsyncOperationState,
        onRetry: (() async -> Void)? = nil
    ) -> some View {
        return StatefulLoadingView(
            state: state,
            onRetry: onRetry
        ) {
            self
        }
    }
}

// MARK: - Custom Error Handling Protocol

public protocol ErrorHandlingProtocol {
    var currentError: AppError? { get }
    var isShowingError: Bool { get set }
    func handle(_ error: AppError)
    func dismissCurrentError()
}

// MARK: - Custom Error Handling Modifier
// Temporarily disabled due to Swift compiler issues - use ErrorHandler.shared instead

// MARK: - Error Notification

extension Notification.Name {
    static let errorOccurred = Notification.Name("errorOccurred")
}

// MARK: - Global Error Functions

/// Post an error to be handled by the error handling system
public func postError(_ error: AppError) {
    NotificationCenter.default.post(
        name: .errorOccurred,
        object: error
    )
}

/// Post any error to be handled by the error handling system
public func postError(_ error: Error) {
    let appError = AppError.from(error)
    postError(appError)
}

// MARK: - Result Extensions

extension Result {
    /// Handle the result using the error handling system
    public func handleResult(
        onSuccess: (Success) -> Void = { _ in },
        context: String = ""
    ) {
        switch self {
        case .success(let value):
            onSuccess(value)
        case .failure(let error):
            let appError = AppError.from(error)
            Task { @MainActor in
                ErrorHandler.shared.handle(appError, context: context)
            }
        }
    }
    
    /// Handle the result with async success handler
    public func handleResult(
        onSuccess: (Success) async -> Void = { _ in },
        context: String = ""
    ) async {
        switch self {
        case .success(let value):
            await onSuccess(value)
        case .failure(let error):
            let appError = AppError.from(error)
            await ErrorHandler.shared.handle(appError, context: context)
        }
    }
}

// MARK: - Task Extensions

extension Task where Success == Void, Failure == Never {
    /// Create a task that handles errors automatically
    public static func withErrorHandling(
        priority: TaskPriority? = nil,
        context: String = "",
        operation: @escaping () async throws -> Void
    ) -> Task<Void, Never> {
        Task(priority: priority) {
            do {
                try await operation()
            } catch {
                let appError = AppError.from(error)
                await ErrorHandler.shared.handle(appError, context: context)
            }
        }
    }
}

// MARK: - Preview

struct ErrorHandlingModifier_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Basic error handling
            VStack {
                Text("Sample View")
                Button("Trigger Error") {
                    postError(AppError.networkUnavailable)
                }
            }
            .errorHandling()
            .previewDisplayName("Basic Error Handling")
            
            // Toast mode
            VStack {
                Text("Sample View")
                Button("Trigger Toast") {
                    ErrorHandler.shared.showToast(for: .deviceOffline)
                }
            }
            .errorHandling(mode: .toast)
            .previewDisplayName("Toast Mode")
            
            // Both modes
            VStack {
                Text("Sample View")
                Button("Trigger Critical") {
                    postError(AppError.dataCorruption)
                }
                Button("Trigger Warning") {
                    postError(AppError.networkTimeout)
                }
            }
            .errorHandling(mode: .both)
            .previewDisplayName("Both Modes")
        }
    }
} 