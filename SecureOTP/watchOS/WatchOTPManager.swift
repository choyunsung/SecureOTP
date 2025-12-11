import SwiftUI

#if os(watchOS)
class WatchOTPManager: ObservableObject {
    @Published var accounts: [OTPAccount] = []
    @Published var isLoading = false
    @Published var isLoggedIn = false
    @Published var errorMessage: String?

    private let api = APIService.shared

    init() {
        checkLoginStatus()
        if isLoggedIn {
            loadAccounts()
        }
    }

    private func checkLoginStatus() {
        if UserDefaults.standard.string(forKey: "auth_token") != nil {
            isLoggedIn = true
        }
    }

    func loadAccounts() {
        // Load from local storage first
        if let data = UserDefaults.standard.data(forKey: "otp_accounts"),
           let decoded = try? JSONDecoder().decode([OTPAccount].self, from: data) {
            DispatchQueue.main.async {
                self.accounts = decoded
            }
        }

        // Then sync from server
        syncFromServer()
    }

    func syncFromServer() {
        guard isLoggedIn else { return }

        isLoading = true
        errorMessage = nil

        Task { @MainActor in
            do {
                let serverAccounts = try await api.getOTPAccounts()
                let otpAccounts = serverAccounts.map { $0.toOTPAccount() }
                self.accounts = otpAccounts
                self.saveAccountsLocally()
                self.isLoading = false
            } catch {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
                print("Watch sync error: \(error)")
            }
        }
    }

    func signInWithEmail(email: String, password: String) {
        isLoading = true
        errorMessage = nil

        Task { @MainActor in
            do {
                _ = try await api.signInWithEmail(email: email, password: password)
                self.isLoggedIn = true
                self.isLoading = false
                self.loadAccounts()
            } catch {
                self.isLoading = false
                self.errorMessage = "Login failed"
                print("Watch login error: \(error)")
            }
        }
    }

    func signOut() {
        api.signOut()
        UserDefaults.standard.removeObject(forKey: "otp_accounts")
        accounts = []
        isLoggedIn = false
    }

    private func saveAccountsLocally() {
        if let encoded = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(encoded, forKey: "otp_accounts")
        }
    }
}
#endif
