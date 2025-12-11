import SwiftUI

#if os(watchOS)
struct WatchContentView: View {
    @StateObject private var otpManager = WatchOTPManager()

    var body: some View {
        NavigationStack {
            if otpManager.isLoggedIn {
                OTPListContent(otpManager: otpManager)
            } else {
                WatchLoginView(otpManager: otpManager)
            }
        }
    }
}

struct WatchLoginView: View {
    @ObservedObject var otpManager: WatchOTPManager
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 40))
                    .foregroundStyle(.blue)

                Text("Secure OTP")
                    .font(.headline)

                TextField("Email", text: $email)
                    .textContentType(.emailAddress)

                SecureField("Password", text: $password)
                    .textContentType(.password)

                if otpManager.isLoading {
                    ProgressView()
                } else {
                    Button("Sign In") {
                        otpManager.signInWithEmail(email: email, password: password)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(email.isEmpty || password.isEmpty)
                }

                if let error = otpManager.errorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }

                Text("Sign in on iPhone first")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}

struct OTPListContent: View {
    @ObservedObject var otpManager: WatchOTPManager

    var body: some View {
        Group {
            if otpManager.isLoading && otpManager.accounts.isEmpty {
                ProgressView("Loading...")
            } else if otpManager.accounts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 40))
                        .foregroundStyle(.blue)

                    Text("No OTP Accounts")
                        .font(.headline)

                    Text("Add accounts on iPhone")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Refresh") {
                        otpManager.syncFromServer()
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                List(otpManager.accounts) { account in
                    WatchOTPRowView(account: account)
                }
                .listStyle(.carousel)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Refresh") {
                        otpManager.syncFromServer()
                    }
                    Button("Sign Out", role: .destructive) {
                        otpManager.signOut()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            otpManager.loadAccounts()
        }
    }
}

struct WatchOTPRowView: View {
    let account: OTPAccount

    @State private var otp = "------"
    @State private var timeRemaining: Double = 30.0
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 8) {
            // Issuer
            if !account.issuer.isEmpty {
                Text(account.issuer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // OTP Code
            Text(formatOTP(otp))
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundStyle(.blue)

            // Account name
            Text(account.accountName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            // Progress
            ProgressView(value: timeRemaining, total: 30)
                .tint(timeRemaining > 10 ? .blue : (timeRemaining > 5 ? .orange : .red))
        }
        .padding(.vertical, 8)
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private func formatOTP(_ code: String) -> String {
        guard code.count == 6 else { return code }
        return String(code.prefix(3)) + " " + String(code.suffix(3))
    }

    private func startTimer() {
        generateOTP()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            let seconds = Double(Calendar.current.component(.second, from: Date()))
            timeRemaining = 30.0 - seconds.truncatingRemainder(dividingBy: 30.0)
            if timeRemaining > 29 {
                generateOTP()
            }
        }
    }

    private func generateOTP() {
        guard let data = Base32.decode(account.secret),
              let totp = TOTP(secret: data, digits: 6, timeInterval: 30, algorithm: .sha1) else {
            otp = "Error"
            return
        }
        otp = totp.generate(time: Date()) ?? "Error"
    }
}

#Preview {
    WatchContentView()
}
#endif
