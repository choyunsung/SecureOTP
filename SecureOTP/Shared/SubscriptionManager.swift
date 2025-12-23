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
        // Load from UserDefaults (in production, verify with StoreKit)
        if let tierString = UserDefaults.standard.string(forKey: "subscription_tier"),
           let tier = SubscriptionTier(rawValue: tierString) {
            currentTier = tier
        }
    }

    func purchaseProSubscription() async {
        await MainActor.run { isProcessing = true }

        // Simulate purchase for now (implement real StoreKit purchase in production)
        do {
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds delay

            await MainActor.run {
                currentTier = .pro
                UserDefaults.standard.set(SubscriptionTier.pro.rawValue, forKey: "subscription_tier")
                isProcessing = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isProcessing = false
            }
        }
    }

    func restorePurchases() async {
        await MainActor.run { isProcessing = true }

        // Simulate restore (implement real StoreKit restore in production)
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay

            await MainActor.run {
                // Check if user has active subscription
                if let tierString = UserDefaults.standard.string(forKey: "subscription_tier"),
                   let tier = SubscriptionTier(rawValue: tierString) {
                    currentTier = tier
                }
                isProcessing = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isProcessing = false
            }
        }
    }

    func cancelSubscription() {
        currentTier = .free
        UserDefaults.standard.set(SubscriptionTier.free.rawValue, forKey: "subscription_tier")
    }

    // For testing/development
    func setProForTesting() {
        currentTier = .pro
        UserDefaults.standard.set(SubscriptionTier.pro.rawValue, forKey: "subscription_tier")
    }
}
