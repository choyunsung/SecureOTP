import Foundation
import LocalAuthentication

/// Manages Face ID / Touch ID biometric authentication
class BiometricAuthManager: ObservableObject {
    static let shared = BiometricAuthManager()

    @Published var isBiometricEnabled = false
    @Published var biometricType: BiometricType = .none

    enum BiometricType {
        case none
        case faceID
        case touchID
        case opticID

        var displayName: String {
            switch self {
            case .none: return "None"
            case .faceID: return "Face ID"
            case .touchID: return "Touch ID"
            case .opticID: return "Optic ID"
            }
        }
    }

    private init() {
        checkBiometricAvailability()
        loadBiometricPreference()
    }

    // MARK: - Biometric Availability

    func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID:
                biometricType = .faceID
            case .touchID:
                biometricType = .touchID
            case .opticID:
                if #available(iOS 17.0, *) {
                    biometricType = .opticID
                } else {
                    biometricType = .none
                }
            case .none:
                biometricType = .none
            @unknown default:
                biometricType = .none
            }
        } else {
            biometricType = .none
            print("⚠️ Biometric not available: \(error?.localizedDescription ?? "Unknown error")")
        }
    }

    // MARK: - Biometric Preference

    func loadBiometricPreference() {
        isBiometricEnabled = UserDefaults.standard.bool(forKey: "biometric_enabled")
    }

    func setBiometricEnabled(_ enabled: Bool) {
        isBiometricEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "biometric_enabled")
        SharedUserDefaults.shared.saveBiometricEnabled(enabled)
        print("💾 Biometric authentication \(enabled ? "enabled" : "disabled")")
    }

    // MARK: - Authentication

    /// Authenticate using Face ID / Touch ID
    func authenticate(reason: String = "Authenticate to access your OTP accounts") async -> Result<Bool, BiometricError> {
        // If biometric is not enabled, skip
        guard isBiometricEnabled else {
            return .success(true)
        }

        // Check if biometric is available
        guard biometricType != .none else {
            return .failure(.notAvailable)
        }

        let context = LAContext()
        var error: NSError?

        // Check if can evaluate policy
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error = error {
                return .failure(.error(error.localizedDescription))
            }
            return .failure(.notAvailable)
        }

        // Perform authentication
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )

            if success {
                print("✅ Biometric authentication successful")
                return .success(true)
            } else {
                print("❌ Biometric authentication failed")
                return .failure(.authenticationFailed)
            }
        } catch let error as LAError {
            print("❌ Biometric authentication error: \(error.localizedDescription)")

            switch error.code {
            case .authenticationFailed:
                return .failure(.authenticationFailed)
            case .userCancel:
                return .failure(.userCancelled)
            case .userFallback:
                return .failure(.userFallback)
            case .systemCancel:
                return .failure(.systemCancelled)
            case .passcodeNotSet:
                return .failure(.passcodeNotSet)
            case .biometryNotAvailable:
                return .failure(.notAvailable)
            case .biometryNotEnrolled:
                return .failure(.notEnrolled)
            case .biometryLockout:
                return .failure(.lockout)
            default:
                return .failure(.error(error.localizedDescription))
            }
        } catch {
            return .failure(.error(error.localizedDescription))
        }
    }

    /// Authenticate with passcode fallback
    func authenticateWithPasscode(reason: String = "Authenticate to access your OTP accounts") async -> Result<Bool, BiometricError> {
        let context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication, // Allows passcode fallback
                localizedReason: reason
            )

            if success {
                print("✅ Authentication successful (biometric or passcode)")
                return .success(true)
            } else {
                return .failure(.authenticationFailed)
            }
        } catch let error as LAError {
            switch error.code {
            case .userCancel:
                return .failure(.userCancelled)
            case .systemCancel:
                return .failure(.systemCancelled)
            default:
                return .failure(.error(error.localizedDescription))
            }
        } catch {
            return .failure(.error(error.localizedDescription))
        }
    }
}

// MARK: - Biometric Error

enum BiometricError: LocalizedError {
    case notAvailable
    case notEnrolled
    case passcodeNotSet
    case lockout
    case authenticationFailed
    case userCancelled
    case userFallback
    case systemCancelled
    case error(String)

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Biometric authentication is not available on this device"
        case .notEnrolled:
            return "No biometric authentication is enrolled. Please set up Face ID or Touch ID in Settings"
        case .passcodeNotSet:
            return "Passcode is not set. Please set up a passcode in Settings"
        case .lockout:
            return "Biometric authentication is locked. Please try again later or use your passcode"
        case .authenticationFailed:
            return "Authentication failed. Please try again"
        case .userCancelled:
            return "Authentication was cancelled"
        case .userFallback:
            return "User chose to use passcode"
        case .systemCancelled:
            return "Authentication was cancelled by the system"
        case .error(let message):
            return message
        }
    }
}
