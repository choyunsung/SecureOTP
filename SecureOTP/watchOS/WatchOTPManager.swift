import SwiftUI
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

#if os(watchOS)
class WatchOTPManager: NSObject, ObservableObject {
    @Published var accounts: [OTPAccount] = []
    @Published var isLoading = false
    @Published var isLoggedIn = false
    @Published var errorMessage: String?

    private let api = APIService.shared

    override init() {
        super.init()
        checkLoginStatus()
        loadAccounts()
        setupWatchConnectivity()
    }

    private func setupWatchConnectivity() {
        #if canImport(WatchConnectivity)
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
        #endif
    }

    private func checkLoginStatus() {
        if UserDefaults.standard.string(forKey: "auth_token") != nil {
            isLoggedIn = true
        }
    }

    func loadAccounts() {
        // PRIORITY 1: Load from shared App Group (fastest, works offline)
        if let sharedAccounts = SharedUserDefaults.shared.loadOTPAccounts() {
            DispatchQueue.main.async {
                self.accounts = sharedAccounts
                print("✅ Watch: Loaded \(sharedAccounts.count) accounts from shared container")
            }
            return // Found data in shared container, no need to check other sources
        }

        // PRIORITY 2: Load from local storage (backward compatibility)
        if let data = UserDefaults.standard.data(forKey: "otp_accounts"),
           let decoded = try? JSONDecoder().decode([OTPAccount].self, from: data) {
            DispatchQueue.main.async {
                self.accounts = decoded
                print("✅ Watch: Loaded \(decoded.count) accounts from local storage")
            }
            // Copy to shared container for future use
            SharedUserDefaults.shared.saveOTPAccounts(decoded)
            return
        }

        // PRIORITY 3: Try to sync from iPhone via WatchConnectivity (if reachable)
        requestAccountsFromiPhone()

        // PRIORITY 4: Sync from server if logged in
        if isLoggedIn {
            syncFromServer()
        }
    }

    func requestAccountsFromiPhone() {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }

        let session = WCSession.default
        guard session.activationState == .activated,
              session.isReachable else {
            print("iPhone not reachable")
            return
        }

        session.sendMessage(["request": "accounts"], replyHandler: { [weak self] reply in
            // Receive accounts
            if let accountsData = reply["accounts"] as? Data,
               let accounts = try? JSONDecoder().decode([OTPAccount].self, from: accountsData) {
                UserDefaults.standard.set(accountsData, forKey: "otp_accounts")
                DispatchQueue.main.async {
                    self?.accounts = accounts
                    print("✅ Watch: Received \(accounts.count) accounts from iPhone")
                }
            }

            // Receive auth token
            if let authToken = reply["auth_token"] as? String {
                UserDefaults.standard.set(authToken, forKey: "auth_token")
                DispatchQueue.main.async {
                    self?.isLoggedIn = true
                    print("✅ Watch: Received auth token from iPhone")
                }
            } else {
                // No auth token means user is not logged in
                UserDefaults.standard.removeObject(forKey: "auth_token")
                DispatchQueue.main.async {
                    self?.isLoggedIn = false
                    print("ℹ️ Watch: No auth token from iPhone")
                }
            }

            // Receive user data
            if let userData = reply["user_data"] as? Data {
                UserDefaults.standard.set(userData, forKey: "current_user")
            }
        }) { error in
            print("Failed to request accounts: \(error.localizedDescription)")
        }
        #endif
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

    func signOut() {
        // Clear local data only - actual sign out happens on iPhone
        UserDefaults.standard.removeObject(forKey: "auth_token")
        UserDefaults.standard.removeObject(forKey: "current_user")
        UserDefaults.standard.removeObject(forKey: "otp_accounts")
        accounts = []
        isLoggedIn = false
        print("✅ Watch: Cleared local data")
    }

    private func saveAccountsLocally() {
        if let encoded = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(encoded, forKey: "otp_accounts")
        }
    }
}

// MARK: - WCSessionDelegate

#if canImport(WatchConnectivity)
extension WatchOTPManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("⌚ Watch WCSession activation FAILED: \(error.localizedDescription)")
        } else {
            print("⌚ Watch WCSession activated successfully")
            print("   - State: \(activationState.rawValue)")
            print("   - Is reachable: \(session.isReachable)")
            print("   - Is companion app installed: \(session.isCompanionAppInstalled)")
        }
    }

    // Receive data from iPhone
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("⌚ Watch: didReceiveMessage called")
        print("   - Message keys: \(message.keys)")

        // Receive accounts
        if let accountsData = message["accounts"] as? Data {
            UserDefaults.standard.set(accountsData, forKey: "otp_accounts")

            if let accounts = try? JSONDecoder().decode([OTPAccount].self, from: accountsData) {
                DispatchQueue.main.async {
                    self.accounts = accounts
                    print("✅ Watch: Received \(accounts.count) accounts from iPhone via message")
                }
            }
        }

        // Receive auth token
        if let authToken = message["auth_token"] as? String {
            UserDefaults.standard.set(authToken, forKey: "auth_token")
            DispatchQueue.main.async {
                self.isLoggedIn = true
                print("✅ Watch: Received auth token from iPhone via message")
            }
        }

        // Receive user data
        if let userData = message["user_data"] as? Data {
            UserDefaults.standard.set(userData, forKey: "current_user")
            print("✅ Watch: Received user data from iPhone via message")
        }
    }

    // Receive application context updates (used for auth sync)
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print("⌚ Watch: didReceiveApplicationContext called")
        print("   - Context keys: \(applicationContext.keys)")

        // Receive accounts
        if let accountsData = applicationContext["accounts"] as? Data {
            UserDefaults.standard.set(accountsData, forKey: "otp_accounts")

            if let accounts = try? JSONDecoder().decode([OTPAccount].self, from: accountsData) {
                DispatchQueue.main.async {
                    self.accounts = accounts
                    print("✅ Watch: Received \(accounts.count) accounts from iPhone via context")
                }
            }
        } else {
            print("⚠️ Watch: No accounts in application context")
        }

        // Receive auth token
        if let authToken = applicationContext["auth_token"] as? String {
            UserDefaults.standard.set(authToken, forKey: "auth_token")
            DispatchQueue.main.async {
                self.isLoggedIn = true
                print("✅ Watch: Synced auth from iPhone - User is logged in")
            }
        } else {
            // No auth token in context means user logged out
            UserDefaults.standard.removeObject(forKey: "auth_token")
            DispatchQueue.main.async {
                self.isLoggedIn = false
                print("✅ Watch: Synced auth from iPhone - User logged out")
            }
        }

        // Receive user data
        if let userData = applicationContext["user_data"] as? Data {
            UserDefaults.standard.set(userData, forKey: "current_user")
            print("✅ Watch: Received user data from iPhone via context")
        } else {
            UserDefaults.standard.removeObject(forKey: "current_user")
        }
    }

    // Receive transferUserInfo (fallback when updateApplicationContext fails)
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        print("⌚ Watch: didReceiveUserInfo called (fallback method)")
        print("   - UserInfo keys: \(userInfo.keys)")

        // Receive accounts
        if let accountsData = userInfo["accounts"] as? Data {
            UserDefaults.standard.set(accountsData, forKey: "otp_accounts")

            if let accounts = try? JSONDecoder().decode([OTPAccount].self, from: accountsData) {
                DispatchQueue.main.async {
                    self.accounts = accounts
                    print("✅ Watch: Received \(accounts.count) accounts from iPhone via transferUserInfo")
                }
            }
        }

        // Receive auth token
        if let authToken = userInfo["auth_token"] as? String {
            UserDefaults.standard.set(authToken, forKey: "auth_token")
            DispatchQueue.main.async {
                self.isLoggedIn = true
                print("✅ Watch: Received auth token via transferUserInfo")
            }
        }

        // Receive user data
        if let userData = userInfo["user_data"] as? Data {
            UserDefaults.standard.set(userData, forKey: "current_user")
            print("✅ Watch: Received user data via transferUserInfo")
        }
    }
}
#endif
#endif
