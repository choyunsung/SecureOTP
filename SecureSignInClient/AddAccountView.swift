import SwiftUI

struct AddAccountView: View {
    // This action will be passed from the parent view to handle adding the account
    var onAdd: (OTPAccount) -> Void

    // Environment property to dismiss the sheet
    @Environment(\.dismiss) private var dismiss

    @State private var issuer: String = ""
    @State private var accountName: String = ""
    @State private var secret: String = ""

    private var isFormValid: Bool {
        !accountName.isEmpty && !secret.isEmpty && Base32.decode(secret) != nil
    }

    var body: some View {
        #if os(iOS)
        iOSView
        #elseif os(macOS)
        macOSView
        #endif
    }

    // MARK: - iOS/iPadOS Optimized View

    #if os(iOS)
    private var iOSView: some View {
        NavigationView {
            Form {
                Section(header: Text("Account Information")) {
                    HStack {
                        Image(systemName: "building.2")
                            .foregroundColor(.blue)
                            .frame(width: 30)
                        TextField("Issuer", text: $issuer)
                            .autocapitalization(.words)
                    }

                    HStack {
                        Image(systemName: "person.circle")
                            .foregroundColor(.blue)
                            .frame(width: 30)
                        TextField("Account Name", text: $accountName)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                    }
                }

                Section(header: Text("Secret Key")) {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(.blue)
                            .frame(width: 30)
                        TextField("Secret Key (Base32)", text: $secret)
                            .autocapitalization(.allCharacters)
                            .disableAutocorrection(true)
                    }

                    if !secret.isEmpty && Base32.decode(secret) == nil {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("Invalid Base32 secret key.")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }

                Section(header: Text("Example")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Issuer: Google")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Account: user@gmail.com")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Secret: JBSWY3DPEHPK3PXP")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Add Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let newAccount = OTPAccount(issuer: issuer, accountName: accountName, secret: secret)
                        onAdd(newAccount)
                        dismiss()
                    }
                    .disabled(!isFormValid)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    #endif

    // MARK: - macOS View

    #if os(macOS)
    private var macOSView: some View {
        VStack(spacing: 20) {
            Text("Add New OTP Account")
                .font(.title)

            Form {
                TextField("Issuer (e.g., Google, Synology)", text: $issuer)
                TextField("Account Name (e.g., user@example.com)", text: $accountName)

                VStack(alignment: .leading) {
                    TextField("Secret Key (Base32)", text: $secret)
                    if !secret.isEmpty && Base32.decode(secret) == nil {
                        Text("Invalid Base32 secret key.")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    let newAccount = OTPAccount(issuer: issuer, accountName: accountName, secret: secret)
                    onAdd(newAccount)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isFormValid)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 400, minHeight: 250)
    }
    #endif
}
