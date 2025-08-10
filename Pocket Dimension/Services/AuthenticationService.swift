import Foundation
import Combine
import SwiftUI

// MARK: - Authentication Service

public class AuthenticationService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var currentUser: AuthenticatedUser?
    @Published public var authenticationState: AuthenticationState = .unauthenticated
    @Published public var isLoading = false
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let keychain = KeychainService()
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Configuration
    
    private let baseURL = "https://your-backend.com" // TODO: Replace with your actual backend
    private let sessionKey = "AuthSession"
    private let userKey = "CurrentUser"
    
    // MARK: - Singleton
    
    public static let shared = AuthenticationService()
    
    private init() {
        restoreSession()
    }
    
    // MARK: - Public Methods
    
    /// Sign in with email and password
    public func signIn(email: String, password: String) async throws {
        await MainActor.run { 
            isLoading = true
            authenticationState = .authenticating
        }
        
        do {
            let request = SignInRequest(email: email, password: password)
            let response: AuthResponseData = try await performAuthRequest(request, endpoint: "/auth/signin")
            
            let user = AuthenticatedUser(
                id: response.user.id,
                email: response.user.email,
                displayName: response.user.displayName,
                createdAt: response.user.createdAt
            )
            
            try await saveSession(response.session, user: user)
            
            await MainActor.run {
                currentUser = user
                authenticationState = .authenticated
                isLoading = false
            }
            
        } catch {
            await MainActor.run {
                authenticationState = .error(error)
                isLoading = false
            }
            throw error
        }
    }
    
    /// Sign up with email and password
    public func signUp(email: String, password: String, displayName: String? = nil) async throws {
        await MainActor.run { 
            isLoading = true
            authenticationState = .authenticating
        }
        
        do {
            let request = SignUpRequest(email: email, password: password, displayName: displayName)
            let response: AuthResponseData = try await performAuthRequest(request, endpoint: "/auth/signup")
            
            let user = AuthenticatedUser(
                id: response.user.id,
                email: response.user.email,
                displayName: response.user.displayName,
                createdAt: response.user.createdAt
            )
            
            try await saveSession(response.session, user: user)
            
            await MainActor.run {
                currentUser = user
                authenticationState = .authenticated
                isLoading = false
            }
            
        } catch {
            await MainActor.run {
                authenticationState = .error(error)
                isLoading = false
            }
            throw error
        }
    }
    
    /// Sign in with Google OAuth
    public func signInWithGoogle() async throws {
        await MainActor.run { 
            isLoading = true
            authenticationState = .authenticating
        }
        
        do {
            // TODO: Implement Google OAuth flow
            // This would integrate with GoogleSignIn SDK
            throw AuthenticationError.notImplemented("Google OAuth not yet implemented")
            
        } catch {
            await MainActor.run {
                authenticationState = .error(error)
                isLoading = false
            }
            throw error
        }
    }
    
    /// Sign in with Apple OAuth
    public func signInWithApple() async throws {
        await MainActor.run { 
            isLoading = true
            authenticationState = .authenticating
        }
        
        do {
            // TODO: Implement Apple OAuth flow
            // This would integrate with AuthenticationServices
            throw AuthenticationError.notImplemented("Apple OAuth not yet implemented")
            
        } catch {
            await MainActor.run {
                authenticationState = .error(error)
                isLoading = false
            }
            throw error
        }
    }
    
    /// Sign out the current user
    public func signOut() async throws {
        await MainActor.run { isLoading = true }
        
        do {
            // Invalidate session on server
            if let session = try? keychain.getSession() {
                try await invalidateSession(session)
            }
            
            // Clear local session
            try clearSession()
            
            await MainActor.run {
                currentUser = nil
                authenticationState = .unauthenticated
                isLoading = false
            }
            
        } catch {
            await MainActor.run {
                authenticationState = .error(error)
                isLoading = false
            }
            throw error
        }
    }
    
    /// Refresh the current session token
    public func refreshSession() async throws {
        guard let session = try? keychain.getSession(),
              let user = currentUser else {
            throw AuthenticationError.noValidSession
        }
        
        do {
            let request = RefreshRequest(refreshToken: session.refreshToken)
            let response: RefreshResponse = try await performAuthRequest(request, endpoint: "/auth/refresh")
            
            let newSession = AuthSession(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken ?? session.refreshToken,
                expiresAt: response.expiresAt
            )
            
            try await saveSession(newSession, user: user)
            
        } catch {
            // If refresh fails, sign out the user
            try await signOut()
            throw error
        }
    }
    
    /// Check if user is currently authenticated
    public var isAuthenticated: Bool {
        return currentUser != nil && authenticationState == .authenticated
    }
    
    /// Get current session token for API calls
    public func getValidAccessToken() async throws -> String {
        guard let session = try? keychain.getSession() else {
            throw AuthenticationError.noValidSession
        }
        
        // Check if token is expired
        if session.isExpired {
            try await refreshSession()
            
            // Get the refreshed session
            guard let refreshedSession = try? keychain.getSession() else {
                throw AuthenticationError.noValidSession
            }
            return refreshedSession.accessToken
        }
        
        return session.accessToken
    }
    
    // MARK: - Private Methods
    
    private func performAuthRequest<T: AuthRequest, R: AuthResponse>(
        _ request: T,
        endpoint: String
    ) async throws -> R {
        guard let url = URL(string: baseURL + endpoint) else {
            throw AuthenticationError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            throw AuthenticationError.encodingError(error)
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthenticationError.networkError("Invalid response")
            }
            
            if httpResponse.statusCode == 200 {
                return try JSONDecoder().decode(R.self, from: data)
            } else {
                // Try to decode error response
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    throw AuthenticationError.serverError(errorResponse.message)
                } else {
                    throw AuthenticationError.networkError("HTTP \(httpResponse.statusCode)")
                }
            }
            
        } catch let error as AuthenticationError {
            throw error
        } catch {
            throw AuthenticationError.networkError(error.localizedDescription)
        }
    }
    
    private func saveSession(_ session: AuthSession, user: AuthenticatedUser) async throws {
        try keychain.saveSession(session)
        
        // Save user data to UserDefaults (non-sensitive data only)
        if let userData = try? JSONEncoder().encode(user) {
            userDefaults.set(userData, forKey: userKey)
        }
    }
    
    private func clearSession() throws {
        try keychain.clearSession()
        userDefaults.removeObject(forKey: userKey)
    }
    
    private func restoreSession() {
        // Check if we have a valid session
        guard let session = try? keychain.getSession(),
              !session.isExpired,
              let userData = userDefaults.data(forKey: userKey),
              let user = try? JSONDecoder().decode(AuthenticatedUser.self, from: userData) else {
            authenticationState = .unauthenticated
            return
        }
        
        currentUser = user
        authenticationState = .authenticated
        
        // Optionally validate session with server in background
        Task {
            do {
                try await refreshSession()
            } catch {
                // If validation fails, silently sign out
                try? await signOut()
            }
        }
    }
    
    private func invalidateSession(_ session: AuthSession) async throws {
        guard let url = URL(string: baseURL + "/auth/signout") else {
            throw AuthenticationError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        
        // Don't throw if this fails - just log it
        do {
            _ = try await URLSession.shared.data(for: urlRequest)
        } catch {
            print("⚠️ Failed to invalidate session on server: \(error)")
        }
    }
}

// MARK: - Supporting Types

public enum AuthenticationState: Equatable {
    case unauthenticated
    case authenticating
    case authenticated
    case error(Error)
    
    public static func == (lhs: AuthenticationState, rhs: AuthenticationState) -> Bool {
        switch (lhs, rhs) {
        case (.unauthenticated, .unauthenticated),
             (.authenticating, .authenticating),
             (.authenticated, .authenticated):
            return true
        case (.error, .error):
            return true // Simplified comparison for errors
        default:
            return false
        }
    }
}

public enum AuthenticationError: Error, LocalizedError {
    case invalidCredentials
    case userAlreadyExists
    case networkError(String)
    case serverError(String)
    case invalidURL
    case encodingError(Error)
    case noValidSession
    case notImplemented(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .userAlreadyExists:
            return "An account with this email already exists"
        case .networkError(let message):
            return "Network error: \(message)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .invalidURL:
            return "Invalid server URL"
        case .encodingError(let error):
            return "Encoding error: \(error.localizedDescription)"
        case .noValidSession:
            return "No valid session found"
        case .notImplemented(let feature):
            return "\(feature) is not yet implemented"
        }
    }
}

// MARK: - Request/Response Types

protocol AuthRequest: Codable {}
protocol AuthResponse: Codable {}

struct SignInRequest: AuthRequest {
    let email: String
    let password: String
}

struct SignUpRequest: AuthRequest {
    let email: String
    let password: String
    let displayName: String?
}

struct RefreshRequest: AuthRequest {
    let refreshToken: String
}

struct AuthResponseData: AuthResponse {
    let user: UserData
    let session: AuthSession
}

struct RefreshResponse: AuthResponse {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date
}

struct UserData: Codable {
    let id: String
    let email: String
    let displayName: String?
    let createdAt: Date
}

struct ErrorResponse: Codable {
    let message: String
    let code: String?
}

// MARK: - Session Types

public struct AuthSession: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    
    var isExpired: Bool {
        return Date() >= expiresAt.addingTimeInterval(-300) // 5 minute buffer
    }
}

// MARK: - Enhanced User Type

public struct AuthenticatedUser: Codable, Identifiable {
    public let id: String
    public let email: String
    public let displayName: String?
    public let createdAt: Date
    
    public init(id: String, email: String, displayName: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.createdAt = createdAt
    }
} 