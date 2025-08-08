import SwiftUI

/// Standardized error alert view with recovery actions
public struct ErrorAlertView: View {
    let error: AppError
    let onDismiss: () -> Void
    let onRecoveryAction: ((ErrorRecoveryAction) async -> Void)?
    
    @StateObject private var errorHandler = ErrorHandler.shared
    @State private var isPerformingAction = false
    
    public init(
        error: AppError,
        onDismiss: @escaping () -> Void,
        onRecoveryAction: ((ErrorRecoveryAction) async -> Void)? = nil
    ) {
        self.error = error
        self.onDismiss = onDismiss
        self.onRecoveryAction = onRecoveryAction
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Error header
            HStack {
                Image(systemName: severityIcon)
                    .foregroundColor(severityColor)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(errorTitle)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(error.errorDescription ?? "An unknown error occurred")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            
            // Recovery actions
            if !error.recoveryActions.isEmpty {
                VStack(spacing: 8) {
                    ForEach(error.recoveryActions, id: \.title) { action in
                        RecoveryActionButton(
                            action: action,
                            isLoading: isPerformingAction,
                            onTap: {
                                await performRecoveryAction(action)
                            }
                        )
                    }
                }
            }
            
            // Dismiss button
            HStack {
                Spacer()
                Button("Dismiss") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
                .shadow(radius: 8)
        )
        .padding()
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
    
    private func performRecoveryAction(_ action: ErrorRecoveryAction) async {
        isPerformingAction = true
        defer { isPerformingAction = false }
        
        if let customHandler = onRecoveryAction {
            await customHandler(action)
        } else {
            await errorHandler.executeRecoveryAction(action)
        }
    }
}

/// Recovery action button component
private struct RecoveryActionButton: View {
    let action: ErrorRecoveryAction
    let isLoading: Bool
    let onTap: () async -> Void
    
    var body: some View {
        Button(action: {
            Task {
                await onTap()
            }
        }) {
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: action.systemImage)
                }
                
                Text(action.title)
                    .font(.body)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.1))
            )
            .foregroundColor(.accentColor)
        }
        .disabled(isLoading)
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

struct ErrorAlertView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Network error
            ErrorAlertView(
                error: .networkUnavailable,
                onDismiss: {}
            )
            .previewDisplayName("Network Error")
            
            // Critical error
            ErrorAlertView(
                error: .dataCorruption,
                onDismiss: {}
            )
            .previewDisplayName("Critical Error")
            
            // Validation error
            ErrorAlertView(
                error: .invalidInput(field: "Email", reason: "Invalid format"),
                onDismiss: {}
            )
            .previewDisplayName("Validation Error")
        }
        .previewLayout(.sizeThatFits)
    }
} 