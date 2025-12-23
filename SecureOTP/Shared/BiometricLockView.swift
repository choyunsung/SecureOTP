import SwiftUI

struct BiometricLockView: View {
    @ObservedObject private var biometricManager = BiometricAuthManager.shared
    @Binding var isUnlocked: Bool
    @State private var isAuthenticating = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.95)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Lock Icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 120, height: 120)

                    Image(systemName: biometricIcon)
                        .font(.system(size: 50))
                        .foregroundStyle(.blue)
                }

                // Title
                VStack(spacing: 12) {
                    Text("SecureOTP")
                        .font(.title.bold())
                        .foregroundStyle(.white)

                    Text("Unlock with \(biometricManager.biometricType.displayName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Unlock Button
                VStack(spacing: 16) {
                    Button(action: authenticate) {
                        HStack(spacing: 12) {
                            if isAuthenticating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: biometricIcon)
                                    .font(.title3)
                            }
                            Text(isAuthenticating ? "Authenticating..." : "Unlock")
                                .font(.headline)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(isAuthenticating)

                    // Use Passcode button
                    Button(action: authenticateWithPasscode) {
                        Text("Use Passcode")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                    .disabled(isAuthenticating)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .alert("Authentication Failed", isPresented: $showError) {
            Button("Try Again", action: authenticate)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            // Auto-trigger authentication when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                authenticate()
            }
        }
    }

    private var biometricIcon: String {
        switch biometricManager.biometricType {
        case .none:
            return "lock.fill"
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .opticID:
            return "opticid"
        }
    }

    private func authenticate() {
        guard !isAuthenticating else { return }
        isAuthenticating = true

        Task {
            let result = await biometricManager.authenticate()

            await MainActor.run {
                isAuthenticating = false

                switch result {
                case .success:
                    withAnimation(.spring()) {
                        isUnlocked = true
                    }
                case .failure(let error):
                    if case .userCancelled = error {
                        // User cancelled, don't show error
                        return
                    }
                    errorMessage = error.localizedDescription ?? "Authentication failed"
                    showError = true
                }
            }
        }
    }

    private func authenticateWithPasscode() {
        guard !isAuthenticating else { return }
        isAuthenticating = true

        Task {
            let result = await biometricManager.authenticateWithPasscode()

            await MainActor.run {
                isAuthenticating = false

                switch result {
                case .success:
                    withAnimation(.spring()) {
                        isUnlocked = true
                    }
                case .failure(let error):
                    if case .userCancelled = error {
                        return
                    }
                    errorMessage = error.localizedDescription ?? "Authentication failed"
                    showError = true
                }
            }
        }
    }
}

#Preview {
    BiometricLockView(isUnlocked: .constant(false))
}
