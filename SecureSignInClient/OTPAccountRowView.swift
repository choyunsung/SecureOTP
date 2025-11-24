import SwiftUI
import Combine

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct OTPAccountRowView: View {
    let account: OTPAccount

    @State private var generatedOTP: String = "------"
    @State private var timeRemaining: Double = 30.0
    @State private var timerSubscription: AnyCancellable?
    @State private var showCopiedFeedback: Bool = false

    var body: some View {
        #if os(iOS)
        iOSRowView
        #elseif os(macOS)
        macOSRowView
        #endif
    }

    // MARK: - iOS/iPadOS Optimized View

    #if os(iOS)
    private var iOSRowView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Left side - Account info with icon
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 48, height: 48)
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 20))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        if !account.issuer.isEmpty {
                            Text(account.issuer)
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        Text(account.accountName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Right side - OTP code and timer
                VStack(alignment: .trailing, spacing: 6) {
                    Button(action: {
                        copyToClipboard()
                        withAnimation {
                            showCopiedFeedback = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation {
                                showCopiedFeedback = false
                            }
                        }
                    }) {
                        HStack(spacing: 8) {
                            Text(formatOTP(generatedOTP))
                                .font(.system(size: 26, weight: .bold, design: .monospaced))
                                .foregroundColor(.blue)

                            if showCopiedFeedback {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.title3)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    // Circular timer
                    ZStack {
                        Circle()
                            .stroke(lineWidth: 3)
                            .opacity(0.2)
                            .foregroundColor(.gray)

                        Circle()
                            .trim(from: 0.0, to: CGFloat(timeRemaining / 30.0))
                            .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .foregroundColor(timerColor)
                            .rotationEffect(Angle(degrees: -90))
                            .animation(.linear(duration: 1.0), value: timeRemaining)

                        Text("\(Int(timeRemaining))")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(timerColor)
                    }
                    .frame(width: 36, height: 36)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .onAppear(perform: setupAndGenerate)
        .onDisappear(perform: stopTimer)
    }

    private func formatOTP(_ code: String) -> String {
        // Format OTP as "123 456" for better readability on iOS
        guard code.count == 6 else { return code }
        let index = code.index(code.startIndex, offsetBy: 3)
        return String(code[..<index]) + " " + String(code[index...])
    }

    private var timerColor: Color {
        if timeRemaining > 10 {
            return .blue
        } else if timeRemaining > 5 {
            return .orange
        } else {
            return .red
        }
    }
    #endif

    // MARK: - macOS View

    #if os(macOS)
    private var macOSRowView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if !account.issuer.isEmpty {
                    Text(account.issuer)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(account.accountName)
                    .font(.body)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(generatedOTP)
                    .font(.system(size: 24, weight: .semibold, design: .monospaced))
                    .foregroundColor(.accentColor)
                    .onTapGesture {
                        copyToClipboard()
                    }

                ProgressView(value: timeRemaining, total: 30.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                    .frame(width: 100)
                    .animation(.linear(duration: 1.0), value: timeRemaining)
            }
        }
        .padding(.vertical, 8)
        .onAppear(perform: setupAndGenerate)
        .onDisappear(perform: stopTimer)
    }
    #endif

    // MARK: - Common Functions

    private func setupAndGenerate() {
        generateOTP()
        startTimer()
    }

    private func generateOTP() {
        guard let secretData = Base32.decode(account.secret) else {
            generatedOTP = "Invalid"
            return
        }
        guard let totp = TOTP(secret: secretData, digits: 6, timeInterval: 30, algorithm: .sha1) else {
            generatedOTP = "Error"
            return
        }
        generatedOTP = totp.generate(time: Date()) ?? "Failed"
    }

    private func startTimer() {
        stopTimer()
        timerSubscription = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                let calendar = Calendar.current
                let seconds = Double(calendar.component(.second, from: Date()))

                timeRemaining = 30.0 - (seconds.truncatingRemainder(dividingBy: 30.0))

                // Regenerate when the timer is about to reset
                if timeRemaining < 1.1 && timeRemaining > 0.9 {
                     // Add a slight delay to avoid showing the old code
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.generateOTP()
                    }
                }
            }
    }

    private func stopTimer() {
        timerSubscription?.cancel()
    }

    private func copyToClipboard() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(generatedOTP, forType: .string)
        #elseif os(iOS)
        UIPasteboard.general.string = generatedOTP
        #endif
    }
}
