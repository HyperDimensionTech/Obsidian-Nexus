import SwiftUI

// MARK: - Authentication View

struct AuthenticationView: View {
    @ObservedObject var authService = AuthenticationService.shared
    @State private var isSignUp = false
    @State private var showingLocalOnlyConfirmation = false
    
    let onAuthenticationSuccess: (AuthenticatedUser) -> Void
    let onContinueLocal: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                AuthenticationHeader()
                
                // Main Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Welcome Section
                        WelcomeSection()
                        
                        // Form Section
                        if isSignUp {
                            SignUpForm(
                                authService: authService,
                                onSuccess: onAuthenticationSuccess,
                                onSwitchToSignIn: { isSignUp = false }
                            )
                        } else {
                            SignInForm(
                                authService: authService,
                                onSuccess: onAuthenticationSuccess,
                                onSwitchToSignUp: { isSignUp = true }
                            )
                        }
                        
                        // OAuth Section
                        OAuthSection(authService: authService, onSuccess: onAuthenticationSuccess)
                            .padding(.horizontal, 0) // Remove extra padding for OAuth buttons
                        
                        // Divider
                        HStack {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(height: 1)
                            
                            Text("or")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                            
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(height: 1)
                        }
                        .padding(.horizontal, 0)
                        
                        // Local-Only Section
                        LocalOnlySection(onContinueLocal: {
                            showingLocalOnlyConfirmation = true
                        })
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 32)
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .background(Color(.systemBackground))
            .confirmationDialog(
                "Continue without account?",
                isPresented: $showingLocalOnlyConfirmation,
                titleVisibility: .visible
            ) {
                Button("Continue Local-Only") {
                    onContinueLocal()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll only be able to use the app on this device. You can always sign up later to sync across devices.")
            }
        }
    }
}

// MARK: - Authentication Header

struct AuthenticationHeader: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "icloud.and.arrow.up")
                .font(.system(size: 50))
                .foregroundColor(.accentColor)
            
            Text("Pocket Dimension")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)
        }
        .padding(.top, 60)
        .padding(.bottom, 20)
    }
}

// MARK: - Welcome Section

struct WelcomeSection: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Welcome to your digital inventory")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            Text("Sync across all your devices and access your inventory from anywhere")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Sign In Form

struct SignInForm: View {
    @ObservedObject var authService: AuthenticationService
    let onSuccess: (AuthenticatedUser) -> Void
    let onSwitchToSignUp: () -> Void
    
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            // Form Fields
            VStack(spacing: 16) {
                CustomTextField(
                    title: "Email",
                    text: $email,
                    keyboardType: .emailAddress,
                    isSecure: false
                )
                
                CustomTextField(
                    title: "Password",
                    text: $password,
                    keyboardType: .default,
                    isSecure: true
                )
            }
            
            // Error Message
            if let errorMessage = errorMessage {
                ErrorMessageView(message: errorMessage)
            }
            
            // Sign In Button
            Button(action: signIn) {
                HStack {
                    if authService.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                    } else {
                        Text("Sign In")
                            .fontWeight(.semibold)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentColor)
                        .opacity(isSignInEnabled ? 1.0 : 0.6)
                )
            }
            .disabled(!isSignInEnabled)
            
            // Switch to Sign Up
            Button(action: onSwitchToSignUp) {
                Text("Don't have an account? **Sign Up**")
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
            }
        }
    }
    
    private var isSignInEnabled: Bool {
        !authService.isLoading && !email.isEmpty && !password.isEmpty
    }
    
    private func signIn() {
        errorMessage = nil
        
        Task {
            do {
                try await authService.signIn(email: email, password: password)
                
                await MainActor.run {
                    if let user = authService.currentUser {
                        onSuccess(user)
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Sign Up Form

struct SignUpForm: View {
    @ObservedObject var authService: AuthenticationService
    let onSuccess: (AuthenticatedUser) -> Void
    let onSwitchToSignIn: () -> Void
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            // Form Fields
            VStack(spacing: 16) {
                CustomTextField(
                    title: "Email",
                    text: $email,
                    keyboardType: .emailAddress,
                    isSecure: false
                )
                
                CustomTextField(
                    title: "Password",
                    text: $password,
                    keyboardType: .default,
                    isSecure: true
                )
                
                CustomTextField(
                    title: "Confirm Password",
                    text: $confirmPassword,
                    keyboardType: .default,
                    isSecure: true
                )
            }
            
            // Password Requirements
            PasswordRequirementsView(password: password, confirmPassword: confirmPassword)
            
            // Error Message
            if let errorMessage = errorMessage {
                ErrorMessageView(message: errorMessage)
            }
            
            // Sign Up Button
            Button(action: signUp) {
                HStack {
                    if authService.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                    } else {
                        Text("Create Account")
                            .fontWeight(.semibold)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentColor)
                        .opacity(isSignUpEnabled ? 1.0 : 0.6)
                )
            }
            .disabled(!isSignUpEnabled)
            
            // Switch to Sign In
            Button(action: onSwitchToSignIn) {
                Text("Already have an account? **Sign In**")
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
            }
        }
    }
    
    private var isSignUpEnabled: Bool {
        !authService.isLoading && !email.isEmpty && !password.isEmpty && 
        password == confirmPassword && password.count >= 6
    }
    
    private func signUp() {
        errorMessage = nil
        
        Task {
            do {
                try await authService.signUp(
                    email: email,
                    password: password,
                    displayName: email.components(separatedBy: "@").first
                )
                
                await MainActor.run {
                    if let user = authService.currentUser {
                        onSuccess(user)
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - OAuth Section

struct OAuthSection: View {
    @ObservedObject var authService: AuthenticationService
    let onSuccess: (AuthenticatedUser) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Google Sign In
            Button(action: signInWithGoogle) {
                HStack(spacing: 12) {
                    Image(systemName: "globe")
                        .font(.system(size: 18, weight: .medium))
                        .frame(width: 20)
                    
                    Text("Continue with Google")
                        .fontWeight(.medium)
                    
                    Spacer()
                }
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        .background(Color(.systemBackground))
                )
            }
            .disabled(authService.isLoading)
            
            // Apple Sign In
            Button(action: signInWithApple) {
                HStack(spacing: 12) {
                    Image(systemName: "applelogo")
                        .font(.system(size: 18, weight: .medium))
                        .frame(width: 20)
                    
                    Text("Continue with Apple")
                        .fontWeight(.medium)
                    
                    Spacer()
                }
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        .background(Color(.systemBackground))
                )
            }
            .disabled(authService.isLoading)
        }
        .padding(.horizontal, 0)
    }
    
    private func signInWithGoogle() {
        Task {
            do {
                try await authService.signInWithGoogle()
                if let user = authService.currentUser {
                    onSuccess(user)
                }
            } catch {
                // Handle OAuth error
                print("Google Sign In error: \(error)")
            }
        }
    }
    
    private func signInWithApple() {
        Task {
            do {
                try await authService.signInWithApple()
                if let user = authService.currentUser {
                    onSuccess(user)
                }
            } catch {
                // Handle OAuth error
                print("Apple Sign In error: \(error)")
            }
        }
    }
}

// MARK: - Local-Only Section

struct LocalOnlySection: View {
    let onContinueLocal: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "iphone")
                        .foregroundColor(.accentColor)
                    
                    Text("Use Local-Only")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                
                Text("Keep your data on this device only. You can always create an account later to sync across devices.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            Button(action: onContinueLocal) {
                Text("Continue Local-Only")
                    .fontWeight(.medium)
                    .foregroundColor(.accentColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.accentColor, lineWidth: 1)
                    )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.accentColor.opacity(0.05))
        )
    }
}

// MARK: - Supporting Views

struct CustomTextField: View {
    let title: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    let isSecure: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Group {
                if isSecure {
                    SecureField(title, text: $text)
                } else {
                    TextField(title, text: $text)
                }
            }
            .font(.body)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
            .keyboardType(keyboardType)
            .autocapitalization(.none)
        }
    }
}

struct PasswordRequirementsView: View {
    let password: String
    let confirmPassword: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RequirementRow(
                text: "At least 6 characters",
                isMet: password.count >= 6
            )
            
            RequirementRow(
                text: "Passwords match",
                isMet: !password.isEmpty && !confirmPassword.isEmpty && password == confirmPassword
            )
        }
        .font(.caption)
        .padding(.horizontal, 4)
    }
}

struct RequirementRow: View {
    let text: String
    let isMet: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isMet ? .green : .secondary)
                .font(.system(size: 12))
            
            Text(text)
                .foregroundColor(isMet ? .green : .secondary)
        }
    }
}

struct ErrorMessageView: View {
    let message: String
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.red)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.1))
        )
    }
} 