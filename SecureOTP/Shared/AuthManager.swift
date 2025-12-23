import SwiftUI
import AuthenticationServices
#if !os(watchOS) && canImport(WatchConnectivity)
import WatchConnectivity
#endif

class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isLoggedIn = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIService.shared

    struct User: Codable {
        let id: String
        let name: String
        let email: String
        let provider: String // "apple", "google", or "email"
    }

    private init() {
        // Check for saved token on init
        if UserDefaults.standard.string(forKey: "auth_token") != nil,
           let userData = UserDefaults.standard.data(forKey: "current_user"),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            self.currentUser = user
            self.isLoggedIn = true
        }
    }

    func signInWithApple(authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }

        let userId = credential.user
        let name = credential.fullName?.givenName ?? "User"
        let email = credential.email

        isLoading = true
        errorMessage = nil

        Task { @MainActor in
            do {
                let response = try await api.signInWithApple(userId: userId, email: email, name: name)
                self.handleAuthSuccess(response, provider: "apple")
            } catch {
                self.handleAuthError(error)
            }
        }
    }

    func signInWithGoogle() {
        // Simulated Google Sign In - In production, use Google Sign-In SDK
        isLoading = true
        errorMessage = nil

        Task { @MainActor in
            do {
                let response = try await api.signInWithGoogle(
                    userId: "google_\(UUID().uuidString)",
                    email: "user@gmail.com",
                    name: "Google User"
                )
                self.handleAuthSuccess(response, provider: "google")
            } catch {
                self.handleAuthError(error)
            }
        }
    }

    func signInWithEmail(name: String, email: String) {
        isLoading = true
        errorMessage = nil

        Task { @MainActor in
            do {
                // Try sign in first, if fails, sign up
                let response: AuthResponse
                do {
                    response = try await api.signInWithEmail(email: email, password: "default123")
                } catch {
                    response = try await api.signUpWithEmail(name: name, email: email, password: "default123")
                }
                self.handleAuthSuccess(response, provider: "email")
            } catch {
                self.handleAuthError(error)
            }
        }
    }

    func signOut() {
        api.signOut()
        UserDefaults.standard.removeObject(forKey: "current_user")
        currentUser = nil
        isLoggedIn = false

        // Notify Apple Watch of sign out
        sendAuthToWatch()
    }

    private func handleAuthSuccess(_ response: AuthResponse, provider: String) {
        let user = User(id: response.user.id, name: response.user.name, email: response.user.email, provider: provider)
        self.currentUser = user
        self.isLoggedIn = true
        self.isLoading = false

        // Save user data
        if let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: "current_user")
        }

        // Send auth data to Apple Watch
        sendAuthToWatch()
    }

    private func handleAuthError(_ error: Error) {
        self.isLoading = false
        self.errorMessage = error.localizedDescription
        print("Auth error: \(error)")
    }

    private func sendAuthToWatch() {
        #if !os(watchOS) && canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }

        let session = WCSession.default
        guard session.activationState == .activated else { return }

        var context: [String: Any] = [:]

        // Send auth token
        if let authToken = UserDefaults.standard.string(forKey: "auth_token") {
            context["auth_token"] = authToken
        }

        // Send user data
        if let userData = UserDefaults.standard.data(forKey: "current_user") {
            context["user_data"] = userData
        }

        // Update application context (persists even when app is not running)
        do {
            try session.updateApplicationContext(context)
            print("✅ Sent auth data to Apple Watch")
        } catch {
            print("❌ Failed to send auth to Watch: \(error.localizedDescription)")
        }
        #endif
    }
}
