import SwiftUI
import Combine
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct OTPRowView: View {
    let account: OTPAccount
    var onDelete: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil

    @State private var otp = "------"
    @State private var timeRemaining: Double = 30.0
    @State private var timer: AnyCancellable?
    @State private var showCopied = false

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 48, height: 48)
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(.blue)
                    .font(.system(size: 20))
            }

            VStack(alignment: .leading, spacing: 4) {
                if !account.issuer.isEmpty {
                    Text(account.issuer)
                        .font(.headline)
                }
                Text(account.accountName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(formatOTP(otp))
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(.blue)

                ZStack {
                    Circle()
                        .stroke(lineWidth: 3)
                        .opacity(0.2)
                    Circle()
                        .trim(from: 0, to: timeRemaining / 30.0)
                        .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .foregroundStyle(timeRemaining > 10 ? .blue : (timeRemaining > 5 ? .orange : .red))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(timeRemaining))")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                }
                .frame(width: 32, height: 32)
            }
        }
        .padding(16)
        #if os(iOS)
        .background(Color.gray.opacity(0.15))
        #else
        .background(Color.gray.opacity(0.2))
        #endif
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture {
            copyToClipboard(otp)
            showCopiedFeedback()
        }
        .contextMenu {
            Button(action: {
                copyToClipboard(otp)
                showCopiedFeedback()
            }) {
                Label("copy_code", systemImage: "doc.on.doc")
            }

            if let onEdit = onEdit {
                Button(action: onEdit) {
                    Label("edit", systemImage: "pencil")
                }
            }

            if let onDelete = onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("delete", systemImage: "trash")
                }
            }
        }
        .overlay(alignment: .center) {
            if showCopied {
                Text("copied")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.75))
                    .clipShape(Capsule())
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showCopied)
        .onAppear { startTimer() }
        .onDisappear { timer?.cancel() }
    }

    private func showCopiedFeedback() {
        showCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showCopied = false
        }
    }

    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }

    private func formatOTP(_ code: String) -> String {
        guard code.count == 6 else { return code }
        return String(code.prefix(3)) + " " + String(code.suffix(3))
    }

    private func startTimer() {
        generateOTP()
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                let seconds = Double(Calendar.current.component(.second, from: Date()))
                timeRemaining = 30.0 - seconds.truncatingRemainder(dividingBy: 30.0)
                if timeRemaining > 29 { generateOTP() }
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
