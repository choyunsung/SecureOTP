//
//  WatchOTPRowView.swift
//  SecureSignInClient
//
//  Apple Watch optimized OTP row view
//

import SwiftUI

#if os(watchOS)
import WatchKit

struct WatchOTPRowView: View {
    let account: OTPAccount
    @State private var otp: String = "------"
    @State private var timeRemaining: Int = 30
    @State private var isPressed: Bool = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Button(action: {
            copyToClipboard()
            WKInterfaceDevice.current().play(.click)
        }) {
            VStack(alignment: .leading, spacing: 10) {
                // Issuer and account name
                VStack(alignment: .leading, spacing: 4) {
                    if !account.issuer.isEmpty {
                        Text(account.issuer)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    Text(account.accountName)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }

                // OTP code with timer
                HStack(alignment: .center, spacing: 12) {
                    // Large OTP code
                    Text(formatOTP(otp))
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                        .tracking(2)

                    Spacer()

                    // Circular timer with seconds
                    VStack(spacing: 2) {
                        CircularProgressView(
                            progress: Double(timeRemaining) / 30.0,
                            timeRemaining: timeRemaining
                        )
                        .frame(width: 36, height: 36)

                        Text("\(timeRemaining)s")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.darkGray).opacity(0.3))
        )
        .onAppear(perform: generateOTP)
        .onReceive(timer) { _ in
            updateOTP()
        }
    }

    private func formatOTP(_ code: String) -> String {
        // Format OTP as "123 456" for better readability
        guard code.count == 6 else { return code }
        let index = code.index(code.startIndex, offsetBy: 3)
        return String(code[..<index]) + " " + String(code[index...])
    }

    private func generateOTP() {
        guard let secretData = Base32.decode(account.secret) else {
            otp = "ERROR"
            return
        }
        guard let totp = TOTP(secret: secretData, digits: 6, timeInterval: 30, algorithm: .sha1) else {
            otp = "ERROR"
            return
        }
        otp = totp.generate(time: Date()) ?? "ERROR"
        timeRemaining = 30 - (Int(Date().timeIntervalSince1970) % 30)
    }

    private func updateOTP() {
        let currentSecond = Int(Date().timeIntervalSince1970) % 30
        timeRemaining = 30 - currentSecond

        if currentSecond == 0 {
            generateOTP()
            WKInterfaceDevice.current().play(.notification)
        }
    }

    private func copyToClipboard() {
        // watchOS doesn't have a system clipboard, but we can show a success feedback
        WKInterfaceDevice.current().play(.success)
    }
}

struct CircularProgressView: View {
    let progress: Double
    let timeRemaining: Int

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(lineWidth: 3)
                .opacity(0.2)
                .foregroundColor(.gray)

            // Progress circle
            Circle()
                .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .foregroundColor(progressColor)
                .rotationEffect(Angle(degrees: -90))
                .animation(.linear(duration: 1.0), value: progress)

            // Time remaining text
            Text("\(timeRemaining)")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(progressColor)
        }
    }

    private var progressColor: Color {
        if timeRemaining > 10 {
            return .blue
        } else if timeRemaining > 5 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Watch List View for ContentView

struct WatchAccountDetailView: View {
    let account: OTPAccount
    @Environment(\.dismiss) private var dismiss
    @State private var otp: String = "------"
    @State private var timeRemaining: Int = 30

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Issuer icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 60, height: 60)
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.blue)
                }

                // Account info
                VStack(spacing: 8) {
                    if !account.issuer.isEmpty {
                        Text(account.issuer)
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    Text(account.accountName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                // Large OTP display
                VStack(spacing: 12) {
                    Text("One-Time Code")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

                    Text(formatOTP(otp))
                        .font(.system(.largeTitle, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                        .tracking(3)

                    // Progress bar
                    CircularProgressView(
                        progress: Double(timeRemaining) / 30.0,
                        timeRemaining: timeRemaining
                    )
                    .frame(width: 50, height: 50)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.darkGray).opacity(0.3))
                )
            }
            .padding()
        }
        .navigationTitle("OTP Code")
        .onAppear(perform: generateOTP)
        .onReceive(timer) { _ in
            updateOTP()
        }
    }

    private func formatOTP(_ code: String) -> String {
        guard code.count == 6 else { return code }
        let index = code.index(code.startIndex, offsetBy: 3)
        return String(code[..<index]) + " " + String(code[index...])
    }

    private func generateOTP() {
        guard let secretData = Base32.decode(account.secret) else {
            otp = "ERROR"
            return
        }
        guard let totp = TOTP(secret: secretData, digits: 6, timeInterval: 30, algorithm: .sha1) else {
            otp = "ERROR"
            return
        }
        otp = totp.generate(time: Date()) ?? "ERROR"
        timeRemaining = 30 - (Int(Date().timeIntervalSince1970) % 30)
    }

    private func updateOTP() {
        let currentSecond = Int(Date().timeIntervalSince1970) % 30
        timeRemaining = 30 - currentSecond

        if currentSecond == 0 {
            generateOTP()
            WKInterfaceDevice.current().play(.notification)
        }
    }
}
#endif
