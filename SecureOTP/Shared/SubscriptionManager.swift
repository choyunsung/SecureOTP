import Foundation
import StoreKit

enum SubscriptionTier: String, Codable {
    case free
    case pro

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Pro"
        }
    }

    var price: String {
        switch self {
        case .free: return "₩0"
        case .pro: return "₩2,900"
        }
    }

    var features: [String] {
        switch self {
        case .free:
            return [
                "local_otp_storage",
                "unlimited_accounts",
                "basic_security"
            ]
        case .pro:
            return [
                "auto_sync",
                "cloud_backup",
                "device_recovery",
                "multi_device_3_5",
                "security_alerts"
            ]
        }
    }
}

class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published var currentTier: SubscriptionTier = .free
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var currentSubscription: SubscriptionResponse?

    // Product IDs (should match App Store Connect)
    private let proMonthlyProductID = "com.quettasoft.secureotp.pro.monthly"

    private init() {
        loadSubscriptionStatus()
    }

    var isPro: Bool {
        currentTier == .pro
    }

    var canSync: Bool {
        isPro
    }

    // MARK: - Subscription Management

    func loadSubscriptionStatus() {
        // Load from UserDefaults first (offline support)
        if let tierString = UserDefaults.standard.string(forKey: "subscription_tier"),
           let tier = SubscriptionTier(rawValue: tierString) {
            currentTier = tier
        }

        // Then sync with server if logged in
        Task {
            await syncWithServer()
        }
    }

    func syncWithServer() async {
        guard UserDefaults.standard.string(forKey: "auth_token") != nil else { return }

        do {
            let response = try await APIService.shared.getSubscriptionStatus()
            await MainActor.run {
                self.currentSubscription = response.subscription
                if response.isSubscribed {
                    self.currentTier = .pro
                    UserDefaults.standard.set(SubscriptionTier.pro.rawValue, forKey: "subscription_tier")
                } else {
                    self.currentTier = .free
                    UserDefaults.standard.set(SubscriptionTier.free.rawValue, forKey: "subscription_tier")
                }
            }
        } catch {
            print("Failed to sync subscription with server: \(error.localizedDescription)")
        }
    }

    func purchaseProSubscription() async {
        await MainActor.run { isProcessing = true }

        // TODO: Implement real StoreKit 2 purchase
        // For now, simulate purchase and sync with server
        do {
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds delay

            // Simulate transaction data (replace with real StoreKit data)
            let transactionId = UUID().uuidString
            let expiresDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())!

            // Verify with server
            let response = try await APIService.shared.verifySubscription(
                productId: proMonthlyProductID,
                transactionId: transactionId,
                originalTransactionId: nil,
                purchaseDate: Date(),
                expiresDate: expiresDate,
                receiptData: nil
            )

            await MainActor.run {
                self.currentSubscription = response.subscription
                self.currentTier = .pro
                UserDefaults.standard.set(SubscriptionTier.pro.rawValue, forKey: "subscription_tier")
                self.isProcessing = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isProcessing = false
            }
        }
    }

    func restorePurchases() async {
        await MainActor.run { isProcessing = true }

        do {
            // TODO: Get real transactions from StoreKit 2
            // For now, just sync with server
            let response = try await APIService.shared.restoreSubscriptions(transactions: [])

            await MainActor.run {
                self.currentSubscription = response.subscription
                if response.isSubscribed {
                    self.currentTier = .pro
                    UserDefaults.standard.set(SubscriptionTier.pro.rawValue, forKey: "subscription_tier")
                } else {
                    self.currentTier = .free
                    UserDefaults.standard.set(SubscriptionTier.free.rawValue, forKey: "subscription_tier")
                }
                self.isProcessing = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isProcessing = false
            }
        }
    }

    func cancelSubscription() async {
        await MainActor.run { isProcessing = true }

        do {
            _ = try await APIService.shared.cancelSubscription()

            await MainActor.run {
                self.currentTier = .free
                self.currentSubscription = nil
                UserDefaults.standard.set(SubscriptionTier.free.rawValue, forKey: "subscription_tier")
                self.isProcessing = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isProcessing = false
            }
        }
    }

    // For testing/development
    func setProForTesting() {
        currentTier = .pro
        UserDefaults.standard.set(SubscriptionTier.pro.rawValue, forKey: "subscription_tier")
    }
}
