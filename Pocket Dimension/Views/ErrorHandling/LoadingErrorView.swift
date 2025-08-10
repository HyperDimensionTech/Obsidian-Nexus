import SwiftUI

/// Loading state with error handling
public struct LoadingErrorView<Content: View>: View {
    let content: Content
    let isLoading: Bool
    let error: AppError?
    let onRetry: (() async -> Void)?
    let loadingMessage: String
    
    @State private var isRetrying = false
    
    public init(
        isLoading: Bool,
        error: AppError? = nil,
        loadingMessage: String = "Loading...",
        onRetry: (() async -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.isLoading = isLoading
        self.error = error
        self.loadingMessage = loadingMessage
        self.onRetry = onRetry
        self.content = content()
    }
    
    public var body: some View {
        ZStack {
            // Content
            content
                .opacity(isLoading || error != nil ? 0.3 : 1.0)
                .disabled(isLoading || error != nil)
            
            // Loading overlay
            if isLoading || isRetrying {
                LoadingOverlay(message: loadingMessage)
            }
            
            // Error overlay
            if let error = error, !isLoading && !isRetrying {
                ErrorOverlay(
                    error: error,
                    onRetry: onRetry != nil ? {
                        await performRetry()
                    } : nil
                )
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isLoading)
        .animation(.easeInOut(duration: 0.3), value: error?.id)
    }
    
    private func performRetry() async {
        guard let onRetry = onRetry else { return }
        
        isRetrying = true
        defer { isRetrying = false }
        
        await onRetry()
    }
}

// MARK: - Loading Overlay

private struct LoadingOverlay: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .progressViewStyle(CircularProgressViewStyle())
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8)
        )
    }
}

// MARK: - Error Overlay

private struct ErrorOverlay: View {
    let error: AppError
    let onRetry: (() async -> Void)?
    
    @State private var isRetrying = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Error icon
            Image(systemName: severityIcon)
                .font(.system(size: 48, weight: .light))
                .foregroundColor(severityColor)
            
            // Error message
            VStack(spacing: 8) {
                Text(errorTitle)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(error.errorDescription ?? "An error occurred")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            
            // Action buttons
            HStack(spacing: 12) {
                if onRetry != nil && error.isRetryable {
                    Button(action: {
                        Task {
                            await retry()
                        }
                    }) {
                        HStack {
                            if isRetrying {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text("Try Again")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.accentColor)
                        .cornerRadius(8)
                    }
                    .disabled(isRetrying)
                }
                
                if error.requiresUserAction {
                    Button(action: {
                        // Handle user action - would need to be coordinated with navigation
                        print("User action required for error: \(error.id)")
                    }) {
                        HStack {
                            Image(systemName: "gear")
                            Text("Settings")
                        }
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8)
        )
        .padding(.horizontal, 16)
    }
    
    private var errorTitle: String {
        switch error.severity {
        case .low:
            return "Information"
        case .medium:
            return "Warning"
        case .high:
            return "Error"
        case .critical:
            return "Critical Error"
        }
    }
    
    private var severityIcon: String {
        switch error.severity {
        case .low:
            return "info.circle"
        case .medium:
            return "exclamationmark.triangle"
        case .high:
            return "xmark.circle"
        case .critical:
            return "exclamationmark.octagon"
        }
    }
    
    private var severityColor: Color {
        switch error.severity {
        case .low:
            return .blue
        case .medium:
            return .orange
        case .high:
            return .red
        case .critical:
            return .purple
        }
    }
    
    private func retry() async {
        guard let onRetry = onRetry else { return }
        
        isRetrying = true
        defer { isRetrying = false }
        
        await onRetry()
    }
}

// MARK: - Convenience Initializers

extension LoadingErrorView {
    /// Initialize with loading state only
    public init(
        isLoading: Bool,
        loadingMessage: String = "Loading...",
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            isLoading: isLoading,
            error: nil,
            loadingMessage: loadingMessage,
            onRetry: nil,
            content: content
        )
    }
    
    /// Initialize with error state only
    public init(
        error: AppError,
        onRetry: (() async -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            isLoading: false,
            error: error,
            loadingMessage: "Loading...",
            onRetry: onRetry,
            content: content
        )
    }
}

// MARK: - Async Operation State

/// Represents the state of an async operation
public enum AsyncOperationState {
    case idle
    case loading(String)
    case success
    case failure(AppError)
    
    public var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }
    
    public var error: AppError? {
        if case .failure(let error) = self {
            return error
        }
        return nil
    }
    
    public var loadingMessage: String {
        if case .loading(let message) = self {
            return message
        }
        return "Loading..."
    }
}

// MARK: - State-based Loading View

/// Loading view that uses AsyncOperationState
public struct StatefulLoadingView<Content: View>: View {
    let content: Content
    let state: AsyncOperationState
    let onRetry: (() async -> Void)?
    
    public init(
        state: AsyncOperationState,
        onRetry: (() async -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.state = state
        self.onRetry = onRetry
        self.content = content()
    }
    
    public var body: some View {
        LoadingErrorView(
            isLoading: state.isLoading,
            error: state.error,
            loadingMessage: state.loadingMessage,
            onRetry: onRetry
        ) {
            content
        }
    }
}

// MARK: - Preview

struct LoadingErrorView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Loading state
            LoadingErrorView(
                isLoading: true,
                loadingMessage: "Loading your items..."
            ) {
                List(0..<10) { index in
                    Text("Item \(index)")
                }
            }
            .previewDisplayName("Loading")
            
            // Error state
            LoadingErrorView(
                error: .networkUnavailable,
                onRetry: {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            ) {
                List(0..<10) { index in
                    Text("Item \(index)")
                }
            }
            .previewDisplayName("Error")
            
            // Success state
            LoadingErrorView(
                isLoading: false
            ) {
                List(0..<10) { index in
                    Text("Item \(index)")
                }
            }
            .previewDisplayName("Success")
        }
    }
} 