import SwiftUI

#if os(watchOS)
struct WatchContentView: View {
    @StateObject private var otpManager = WatchOTPManager()

    var body: some View {
        NavigationStack {
            OTPListContent(otpManager: otpManager)
        }
    }
}

struct OTPListContent: View {
    @ObservedObject var otpManager: WatchOTPManager
    @State private var showActions = false

    var body: some View {
        Group {
            if otpManager.isLoading && otpManager.accounts.isEmpty {
                ProgressView("Loading...")
            } else if otpManager.accounts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 40))
                        .foregroundStyle(.blue)

                    Text("no_otp_accounts")
                        .font(.headline)

                    Text("add_accounts_on_iphone")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("refresh") {
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
                Button(action: { showActions = true }) {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showActions) {
            NavigationStack {
                List {
                    Button("sync_from_iphone") {
                        otpManager.requestAccountsFromiPhone()
                        showActions = false
                    }
                    Button("refresh_from_server") {
                        otpManager.syncFromServer()
                        showActions = false
                    }
                    if otpManager.isLoggedIn {
                        Button("sign_out", role: .destructive) {
                            otpManager.signOut()
                            showActions = false
                        }
                    }
                }
                .navigationTitle("settings")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("done") {
                            showActions = false
                        }
                    }
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
