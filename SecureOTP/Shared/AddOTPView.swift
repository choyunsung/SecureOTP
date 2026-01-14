import SwiftUI

struct AddOTPView: View {
    var onAdd: (OTPAccount) -> Void
    var onCancel: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var issuer = ""
    @State private var accountName = ""
    @State private var secret = ""
    @State private var showQRScanner = false

    private var isValid: Bool {
        !accountName.isEmpty && !secret.isEmpty && Base32.decode(secret) != nil
    }

    var body: some View {
        #if os(macOS)
        VStack {
            formContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .onChange(of: showQRScanner) { _, newValue in
            if newValue {
                showQRScanner = false
                MagnifierScannerController.startScanning { [self] code in
                    handleScannedCode(code)
                }
            }
        }
        #elseif targetEnvironment(macCatalyst)
        NavigationStack {
            formContent
                .navigationTitle("Add Account")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
                .sheet(isPresented: $showQRScanner) {
                    CatalystScreenQRScannerView { scannedCode in
                        handleScannedCode(scannedCode)
                    }
                }
        }
        #else
        NavigationStack {
            formContent
                .navigationTitle("Add Account")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
                .sheet(isPresented: $showQRScanner) {
                    QRScannerView { scannedCode in
                        handleScannedCode(scannedCode)
                    }
                }
        }
        #endif
    }

    private var formContent: some View {
        VStack(spacing: 20) {
            // QR Scan Button
            Button(action: { showQRScanner = true }) {
                HStack {
                    #if os(macOS) || targetEnvironment(macCatalyst)
                    Image(systemName: "rectangle.dashed.and.paperclip")
                        .font(.system(size: 24))
                    Text("Scan QR from Screen")
                        .fontWeight(.medium)
                    #else
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 24))
                    Text("Scan QR Code")
                        .fontWeight(.medium)
                    #endif
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.top, 20)

            HStack {
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 1)
                Text("OR ENTER MANUALLY")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 1)
            }

            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Issuer")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("Google, GitHub, etc.", text: $issuer)
                        .textFieldStyle(.plain)
                        .padding()
                        #if os(iOS)
                        .background(Color.gray.opacity(0.15))
                        #else
                        .background(Color.gray.opacity(0.2))
                        #endif
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Account")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("user@example.com", text: $accountName)
                        .textFieldStyle(.plain)
                        #if os(iOS)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        #endif
                        .padding()
                        #if os(iOS)
                        .background(Color.gray.opacity(0.15))
                        #else
                        .background(Color.gray.opacity(0.2))
                        #endif
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Secret Key")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("Base32 secret", text: $secret)
                        .textFieldStyle(.plain)
                        #if os(iOS)
                        .autocapitalization(.allCharacters)
                        #endif
                        .autocorrectionDisabled()
                        .padding()
                        #if os(iOS)
                        .background(Color.gray.opacity(0.15))
                        #else
                        .background(Color.gray.opacity(0.2))
                        #endif
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    if !secret.isEmpty && Base32.decode(secret) == nil {
                        Text("Invalid Base32 key")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }

            Button(action: {
                onAdd(OTPAccount(issuer: issuer, accountName: accountName, secret: secret))
                #if !os(macOS)
                dismiss()
                #endif
            }) {
                Text("Add Account")
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(isValid ? LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing) : LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(!isValid)

            #if os(macOS)
            Button("Cancel") {
                if let onCancel = onCancel {
                    onCancel()
                }
            }
            #endif

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func handleScannedCode(_ code: String) {
        print("DEBUG: handleScannedCode called with: \(code)")
        if let account = OTPAccount.parse(uri: code) {
            print("DEBUG: Parsed account - issuer: \(account.issuer), account: \(account.accountName)")
            issuer = account.issuer
            accountName = account.accountName
            secret = account.secret
        } else {
            print("DEBUG: Failed to parse OTP URI")
        }
    }
}
