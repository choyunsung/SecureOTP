import SwiftUI

struct BiometricSettingsView: View {
    @ObservedObject private var biometricManager = BiometricAuthManager.shared
    @State private var showingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 16) {
                        Image(systemName: biometricIcon)
                            .font(.system(size: 44))
                            .foregroundStyle(.blue)
                            .frame(width: 60)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(biometricTitle)
                                .font(.headline)
                            Text(biometricDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)

                    if biometricManager.biometricType != .none {
                        Toggle(isOn: $biometricManager.isBiometricEnabled) {
                            Text("Enable \(biometricManager.biometricType.displayName)")
                        }
                        .onChange(of: biometricManager.isBiometricEnabled) { oldValue, newValue in
                            handleBiometricToggle(enabled: newValue)
                        }
                    }
                }
            } header: {
                Text("Biometric Authentication")
            } footer: {
                if biometricManager.biometricType != .none {
                    Text("When enabled, you'll need to authenticate with \(biometricManager.biometricType.displayName) to access your OTP accounts.")
                        .font(.caption)
                } else {
                    Text("Biometric authentication is not available on this device.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            if biometricManager.biometricType != .none && biometricManager.isBiometricEnabled {
                Section {
                    Button(action: testBiometric) {
                        Label("Test \(biometricManager.biometricType.displayName)", systemImage: "play.circle")
                    }
                } header: {
                    Text("Test")
                } footer: {
                    Text("Test your biometric authentication to ensure it's working correctly.")
                        .font(.caption)
                }
            }

            Section {
                InfoRow(title: "Security", value: "Biometric data never leaves your device")
                InfoRow(title: "Privacy", value: "Your OTP secrets are protected")
                InfoRow(title: "Fallback", value: "Use device passcode if biometric fails")
            } header: {
                Text("Information")
            }
        }
        .navigationTitle("Face ID & Touch ID")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Biometric Test", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    private var biometricIcon: String {
        switch biometricManager.biometricType {
        case .none:
            return "exclamationmark.triangle"
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .opticID:
            return "opticid"
        }
    }

    private var biometricTitle: String {
        switch biometricManager.biometricType {
        case .none:
            return "Not Available"
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        }
    }

    private var biometricDescription: String {
        switch biometricManager.biometricType {
        case .none:
            return "Biometric authentication is not available on this device"
        case .faceID:
            return "Use your face to unlock your OTP accounts"
        case .touchID:
            return "Use your fingerprint to unlock your OTP accounts"
        case .opticID:
            return "Use your eyes to unlock your OTP accounts"
        }
    }

    private func handleBiometricToggle(enabled: Bool) {
        if enabled {
            // Test biometric when enabling
            Task {
                let result = await biometricManager.authenticate(reason: "Verify \(biometricManager.biometricType.displayName) to enable")

                await MainActor.run {
                    switch result {
                    case .success:
                        biometricManager.setBiometricEnabled(true)
                        alertMessage = "\(biometricManager.biometricType.displayName) has been enabled successfully!"
                        showingAlert = true
                    case .failure(let error):
                        biometricManager.isBiometricEnabled = false
                        alertMessage = error.localizedDescription ?? "Failed to enable biometric authentication"
                        showingAlert = true
                    }
                }
            }
        } else {
            biometricManager.setBiometricEnabled(false)
            alertMessage = "\(biometricManager.biometricType.displayName) has been disabled."
            showingAlert = true
        }
    }

    private func testBiometric() {
        Task {
            let result = await biometricManager.authenticate(reason: "Test \(biometricManager.biometricType.displayName)")

            await MainActor.run {
                switch result {
                case .success:
                    alertMessage = "✅ Authentication successful!"
                case .failure(let error):
                    alertMessage = "❌ " + (error.localizedDescription ?? "Authentication failed")
                }
                showingAlert = true
            }
        }
    }
}

struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

#Preview {
    NavigationStack {
        BiometricSettingsView()
    }
}
