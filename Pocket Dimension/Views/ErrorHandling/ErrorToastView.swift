import SwiftUI

/// Toast notification for non-critical errors
public struct ErrorToastView: View {
    let error: AppError
    let onDismiss: () -> Void
    let onRetry: (() async -> Void)?
    
    @State private var isVisible = false
    @State private var isRetrying = false
    
    public init(
        error: AppError,
        onDismiss: @escaping () -> Void,
        onRetry: (() async -> Void)? = nil
    ) {
        self.error = error
        self.onDismiss = onDismiss
        self.onRetry = onRetry
    }
    
    public var body: some View {
        VStack {
            Spacer()
            
            if isVisible {
                HStack(spacing: 12) {
                    // Error icon
                    Image(systemName: severityIcon)
                        .foregroundColor(severityColor)
                        .font(.system(size: 20, weight: .medium))
                    
                    // Error message
                    VStack(alignment: .leading, spacing: 2) {
                        Text(errorTitle)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text(error.errorDescription ?? "An error occurred")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    // Action buttons
                    HStack(spacing: 8) {
                        if onRetry != nil && error.isRetryable {
                            Button(action: {
                                Task {
                                    await retry()
                                }
                            }) {
                                if isRetrying {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 14, weight: .medium))
                                }
                            }
                            .disabled(isRetrying)
                        }
                        
                        Button(action: dismiss) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .medium))
                        }
                    }
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                )
                .padding(.horizontal, 16)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
                .onTapGesture {
                    // Dismiss on tap if not retryable
                    if !error.isRetryable {
                        dismiss()
                    }
                }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isVisible)
        .onAppear {
            withAnimation {
                isVisible = true
            }
            
            // Auto-dismiss after delay for non-critical errors
            if !error.isCritical && !error.requiresUserAction {
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    dismiss()
                }
            }
        }
    }
    
    private var errorTitle: String {
        switch error.severity {
        case .low:
            return "Info"
        case .medium:
            return "Warning"
        case .high:
            return "Error"
        case .critical:
            return "Critical"
        }
    }
    
    private var severityIcon: String {
        switch error.severity {
        case .low:
            return "info.circle.fill"
        case .medium:
            return "exclamationmark.triangle.fill"
        case .high:
            return "xmark.circle.fill"
        case .critical:
            return "exclamationmark.octagon.fill"
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
    
    private func dismiss() {
        withAnimation {
            isVisible = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
    
    private func retry() async {
        guard let onRetry = onRetry else { return }
        
        isRetrying = true
        defer { isRetrying = false }
        
        await onRetry()
        dismiss()
    }
}

// MARK: - Toast Container

/// Container for managing multiple toast notifications
public struct ToastContainer: View {
    @State private var toasts: [ToastData] = []
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 8) {
            ForEach(toasts) { toast in
                ErrorToastView(
                    error: toast.error,
                    onDismiss: {
                        removeToast(toast)
                    },
                    onRetry: toast.onRetry
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showErrorToast)) { notification in
            if let toastData = notification.object as? ToastData {
                showToast(toastData)
            }
        }
    }
    
    private func showToast(_ toast: ToastData) {
        toasts.append(toast)
        
        // Limit to 3 toasts maximum
        if toasts.count > 3 {
            toasts.removeFirst()
        }
    }
    
    private func removeToast(_ toast: ToastData) {
        toasts.removeAll { $0.id == toast.id }
    }
}

// MARK: - Supporting Types

public struct ToastData: Identifiable {
    public let id = UUID()
    public let error: AppError
    public let onRetry: (() async -> Void)?
    
    public init(error: AppError, onRetry: (() async -> Void)? = nil) {
        self.error = error
        self.onRetry = onRetry
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let showErrorToast = Notification.Name("showErrorToast")
}

// MARK: - Convenience Methods

extension ErrorHandler {
    /// Show a toast notification for an error
    public func showToast(for error: AppError, onRetry: (() async -> Void)? = nil) {
        let toastData = ToastData(error: error, onRetry: onRetry)
        NotificationCenter.default.post(
            name: .showErrorToast,
            object: toastData
        )
    }
    
    /// Show a toast notification for any error
    public func showToast(for error: Error, onRetry: (() async -> Void)? = nil) {
        let appError = AppError.from(error)
        showToast(for: appError, onRetry: onRetry)
    }
}

// MARK: - Preview

struct ErrorToastView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Network error with retry
            ErrorToastView(
                error: .networkTimeout,
                onDismiss: {},
                onRetry: {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            )
            .previewDisplayName("Network Error")
            
            // Info toast
            ErrorToastView(
                error: .deviceOffline,
                onDismiss: {}
            )
            .previewDisplayName("Info Toast")
            
            // Toast container with multiple toasts
            ToastContainer()
                .previewDisplayName("Toast Container")
        }
        .previewLayout(.sizeThatFits)
    }
} 