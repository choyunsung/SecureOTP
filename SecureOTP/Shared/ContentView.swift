import SwiftUI

struct ContentView: View {
    @ObservedObject private var authManager = AuthManager.shared

    var body: some View {
        Group {
            // TEMPORARY: Bypass login for testing
            #if DEBUG
            #if os(iOS)
            MainTabView()
            #else
            MainSidebarView()
            #endif
            #else
            if authManager.isLoggedIn {
                #if os(iOS)
                MainTabView()
                #else
                MainSidebarView()
                #endif
            } else {
                SignInView()
            }
            #endif
        }
        .animation(.easeInOut, value: authManager.isLoggedIn)
        .onAppear {
            #if DEBUG
            // Add test OTP data for testing
            addTestOTPData()
            #endif
        }
    }

    private func addTestOTPData() {
        // Check if test data already exists
        if let data = UserDefaults.standard.data(forKey: "otp_accounts"),
           let accounts = try? JSONDecoder().decode([OTPAccount].self, from: data),
           !accounts.isEmpty {
            return // Test data already exists
        }

        // Add test OTP accounts
        let testAccounts = [
            OTPAccount(
                issuer: "Google",
                accountName: "test@gmail.com",
                secret: "JBSWY3DPEHPK3PXP"
            ),
            OTPAccount(
                issuer: "GitHub",
                accountName: "testuser",
                secret: "HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ"
            ),
            OTPAccount(
                issuer: "Microsoft",
                accountName: "test@outlook.com",
                secret: "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"
            )
        ]

        if let encoded = try? JSONEncoder().encode(testAccounts) {
            UserDefaults.standard.set(encoded, forKey: "otp_accounts")
        }
    }
}
