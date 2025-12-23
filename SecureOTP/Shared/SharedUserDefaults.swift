import Foundation

/// Shared UserDefaults for iPhone and Watch apps using App Groups
class SharedUserDefaults {
    static let shared = SharedUserDefaults()

    private let appGroupID = "group.com.quettasoft.app.SecureOTP"
    private let defaults: UserDefaults?

    private init() {
        defaults = UserDefaults(suiteName: appGroupID)
        if defaults == nil {
            print("⚠️ Failed to create shared UserDefaults with App Group: \(appGroupID)")
        } else {
            print("✅ Shared UserDefaults initialized with App Group: \(appGroupID)")
        }
    }

    // MARK: - OTP Accounts

    func saveOTPAccounts(_ accounts: [OTPAccount]) {
        guard let encoded = try? JSONEncoder().encode(accounts) else {
            print("❌ Failed to encode OTP accounts")
            return
        }

        defaults?.set(encoded, forKey: "otp_accounts")
        defaults?.synchronize()
        print("💾 Saved \(accounts.count) OTP accounts to shared container")
    }

    func loadOTPAccounts() -> [OTPAccount]? {
        guard let data = defaults?.data(forKey: "otp_accounts"),
              let decoded = try? JSONDecoder().decode([OTPAccount].self, from: data) else {
            print("ℹ️ No OTP accounts in shared container")
            return nil
        }

        print("📖 Loaded \(decoded.count) OTP accounts from shared container")
        return decoded
    }

    // MARK: - Auth Token

    func saveAuthToken(_ token: String) {
        defaults?.set(token, forKey: "auth_token")
        defaults?.synchronize()
        print("💾 Saved auth token to shared container")
    }

    func loadAuthToken() -> String? {
        return defaults?.string(forKey: "auth_token")
    }

    func removeAuthToken() {
        defaults?.removeObject(forKey: "auth_token")
        defaults?.synchronize()
        print("🗑️ Removed auth token from shared container")
    }

    // MARK: - User Data

    func saveUserData(_ data: Data) {
        defaults?.set(data, forKey: "current_user")
        defaults?.synchronize()
        print("💾 Saved user data to shared container")
    }

    func loadUserData() -> Data? {
        return defaults?.data(forKey: "current_user")
    }

    func removeUserData() {
        defaults?.removeObject(forKey: "current_user")
        defaults?.synchronize()
        print("🗑️ Removed user data from shared container")
    }

    // MARK: - Biometric Settings

    func saveBiometricEnabled(_ enabled: Bool) {
        defaults?.set(enabled, forKey: "biometric_enabled")
        defaults?.synchronize()
        print("💾 Saved biometric enabled: \(enabled) to shared container")
    }

    func loadBiometricEnabled() -> Bool {
        return defaults?.bool(forKey: "biometric_enabled") ?? false
    }
}
