import Foundation
import StoreKit

// MARK: - Subscription Tier

enum SubscriptionTier: String, Codable {
    case free
    case pro

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Pro"
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

// MARK: - Subscription Manager

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    // MARK: - Published Properties

    @Published var currentTier: SubscriptionTier = .free
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var currentSubscription: SubscriptionResponse?

    // MARK: - Product IDs

    static let proMonthlyProductID = "com.quettasoft.secureotp.pro.monthly"
    static let proYearlyProductID = "com.quettasoft.secureotp.pro.yearly"

    private let productIDs: Set<String> = [
        proMonthlyProductID,
        proYearlyProductID
    ]

    // MARK: - Transaction Listener

    private var transactionListener: Task<Void, Error>?

    // MARK: - Initialization

    private init() {
        // Start listening for transactions
        transactionListener = listenForTransactions()

        // Load products and subscription status
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Computed Properties

    var isPro: Bool {
        currentTier == .pro
    }

    var canSync: Bool {
        isPro
    }

    var monthlyProduct: Product? {
        products.first { $0.id == Self.proMonthlyProductID }
    }

    var yearlyProduct: Product? {
        products.first { $0.id == Self.proYearlyProductID }
    }

    // MARK: - Load Products

    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: productIDs)
            products = storeProducts.sorted { $0.price < $1.price }
            print("✅ Loaded \(products.count) products")
            for product in products {
                print("   - \(product.id): \(product.displayPrice)")
            }
        } catch {
            print("❌ Failed to load products: \(error.localizedDescription)")
            errorMessage = "Failed to load products"
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async -> Bool {
        isProcessing = true
        errorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)

                // Update subscription status
                await updateSubscriptionStatus()

                // Sync with server
                await syncWithServer(transaction: transaction)

                // Finish the transaction
                await transaction.finish()

                isProcessing = false
                return true

            case .userCancelled:
                print("ℹ️ User cancelled purchase")
                isProcessing = false
                return false

            case .pending:
                print("⏳ Purchase pending (awaiting approval)")
                errorMessage = "Purchase is pending approval"
                isProcessing = false
                return false

            @unknown default:
                isProcessing = false
                return false
            }
        } catch {
            print("❌ Purchase failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isProcessing = false
            return false
        }
    }

    // Convenience method for purchasing Pro monthly
    func purchaseProSubscription() async {
        guard let product = monthlyProduct else {
            errorMessage = "Product not available"
            return
        }
        _ = await purchase(product)
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        isProcessing = true
        errorMessage = nil

        do {
            // Sync with App Store
            try await AppStore.sync()

            // Update local status
            await updateSubscriptionStatus()

            // Sync with server
            await syncRestoredPurchasesWithServer()

            isProcessing = false
        } catch {
            print("❌ Restore failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isProcessing = false
        }
    }

    // MARK: - Update Subscription Status

    func updateSubscriptionStatus() async {
        var hasActiveSubscription = false

        // Check for active subscriptions
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                if productIDs.contains(transaction.productID) {
                    purchasedProductIDs.insert(transaction.productID)
                    hasActiveSubscription = true
                }
            } catch {
                print("⚠️ Transaction verification failed: \(error)")
            }
        }

        // Update tier
        if hasActiveSubscription {
            currentTier = .pro
            UserDefaults.standard.set(SubscriptionTier.pro.rawValue, forKey: "subscription_tier")
        } else {
            currentTier = .free
            purchasedProductIDs.removeAll()
            UserDefaults.standard.set(SubscriptionTier.free.rawValue, forKey: "subscription_tier")
        }

        print("📊 Subscription status: \(currentTier.displayName)")
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            // Listen for transaction updates
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)

                    // Update subscription status on main actor
                    await MainActor.run {
                        Task {
                            await self.updateSubscriptionStatus()
                        }
                    }

                    // Sync with server
                    await self.syncWithServer(transaction: transaction)

                    // Finish the transaction
                    await transaction.finish()
                } catch {
                    print("⚠️ Transaction update verification failed: \(error)")
                }
            }
        }
    }

    // MARK: - Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let signedType):
            return signedType
        }
    }

    // MARK: - Server Sync

    private func syncWithServer(transaction: Transaction) async {
        guard UserDefaults.standard.string(forKey: "auth_token") != nil else { return }

        do {
            let response = try await APIService.shared.verifySubscription(
                productId: transaction.productID,
                transactionId: String(transaction.id),
                originalTransactionId: String(transaction.originalID),
                purchaseDate: transaction.purchaseDate,
                expiresDate: transaction.expirationDate,
                receiptData: nil
            )

            await MainActor.run {
                self.currentSubscription = response.subscription
            }

            print("✅ Synced subscription with server")
        } catch {
            print("⚠️ Failed to sync with server: \(error.localizedDescription)")
        }
    }

    private func syncRestoredPurchasesWithServer() async {
        guard UserDefaults.standard.string(forKey: "auth_token") != nil else { return }

        var transactions: [[String: Any]] = []

        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                var txnData: [String: Any] = [
                    "productId": transaction.productID,
                    "transactionId": String(transaction.id),
                    "purchaseDate": ISO8601DateFormatter().string(from: transaction.purchaseDate)
                ]

                if let expiresDate = transaction.expirationDate {
                    txnData["expiresDate"] = ISO8601DateFormatter().string(from: expiresDate)
                }

                txnData["originalTransactionId"] = String(transaction.originalID)

                transactions.append(txnData)
            }
        }

        guard !transactions.isEmpty else { return }

        do {
            let response = try await APIService.shared.restoreSubscriptions(transactions: transactions)
            await MainActor.run {
                self.currentSubscription = response.subscription
                if response.isSubscribed {
                    self.currentTier = .pro
                }
            }
            print("✅ Restored \(transactions.count) purchases with server")
        } catch {
            print("⚠️ Failed to restore purchases with server: \(error.localizedDescription)")
        }
    }

    func syncWithServer() async {
        guard UserDefaults.standard.string(forKey: "auth_token") != nil else { return }

        do {
            let response = try await APIService.shared.getSubscriptionStatus()
            currentSubscription = response.subscription
            if response.isSubscribed {
                currentTier = .pro
                UserDefaults.standard.set(SubscriptionTier.pro.rawValue, forKey: "subscription_tier")
            }
        } catch {
            print("⚠️ Failed to sync subscription status: \(error.localizedDescription)")
        }
    }

    // MARK: - Subscription Info

    func getSubscriptionInfo() async -> (expirationDate: Date?, willRenew: Bool)? {
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result),
               productIDs.contains(transaction.productID) {

                // Check renewal status from revocation date
                // If revocationDate is nil, subscription is still active/renewing
                let willRenew = transaction.revocationDate == nil

                return (transaction.expirationDate, willRenew)
            }
        }
        return nil
    }

    // MARK: - Manage Subscription

    func showManageSubscriptions() async {
        #if os(iOS)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            do {
                try await AppStore.showManageSubscriptions(in: windowScene)
            } catch {
                print("❌ Failed to show manage subscriptions: \(error)")
            }
        }
        #endif
    }

    // MARK: - Testing (Development Only)

    #if DEBUG
    func setProForTesting() {
        currentTier = .pro
        UserDefaults.standard.set(SubscriptionTier.pro.rawValue, forKey: "subscription_tier")
    }

    func resetForTesting() {
        currentTier = .free
        purchasedProductIDs.removeAll()
        UserDefaults.standard.set(SubscriptionTier.free.rawValue, forKey: "subscription_tier")
    }
    #endif
}

// MARK: - Product Extension

extension Product {
    var localizedPeriod: String {
        guard let subscription = self.subscription else { return "" }

        let unit = subscription.subscriptionPeriod.unit
        let value = subscription.subscriptionPeriod.value

        switch unit {
        case .day:
            return value == 1 ? "day" : "\(value) days"
        case .week:
            return value == 1 ? "week" : "\(value) weeks"
        case .month:
            return value == 1 ? "month" : "\(value) months"
        case .year:
            return value == 1 ? "year" : "\(value) years"
        @unknown default:
            return ""
        }
    }
}
