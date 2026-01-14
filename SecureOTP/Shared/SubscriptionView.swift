import SwiftUI

struct SubscriptionView: View {
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 100, height: 100)
                            Image(systemName: "shield.checkered")
                                .font(.system(size: 50))
                                .foregroundStyle(.white)
                        }

                        Text("unlock_premium_features")
                            .font(.title)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)

                        Text("sync_protect_access")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 20)

                    // Pro Features Grid
                    VStack(spacing: 16) {
                        ForEach(SubscriptionTier.pro.features, id: \.self) { feature in
                            FeatureRow(feature: feature)
                        }
                    }
                    .padding(.horizontal, 20)

                    // Pricing Card
                    VStack(spacing: 16) {
                        if subscriptionManager.isPro {
                            // Already subscribed
                            VStack(spacing: 12) {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.title2)
                                    Text("pro_active")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                }

                                Text("thank_you_for_subscribing")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(24)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.green.opacity(0.1))
                            )
                        } else {
                            // Subscribe button
                            VStack(spacing: 12) {
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text(priceString)
                                        .font(.system(size: 40, weight: .bold))
                                        .foregroundStyle(.primary)
                                    Text("per_month")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Text("billed_monthly")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Button(action: {
                                    Task {
                                        await subscriptionManager.purchaseProSubscription()
                                    }
                                }) {
                                    Group {
                                        if subscriptionManager.isProcessing {
                                            ProgressView()
                                                .progressViewStyle(.circular)
                                                .tint(.white)
                                        } else {
                                            Text("start_free_trial")
                                                .fontWeight(.semibold)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                                .disabled(subscriptionManager.isProcessing)

                                Text("auto_renewable_subscription")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(24)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemGray6))
                            )
                        }
                    }
                    .padding(.horizontal, 20)

                    // Restore Purchases
                    if !subscriptionManager.isPro {
                        Button("restore_purchases") {
                            Task {
                                await subscriptionManager.restorePurchases()
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                        // Terms
                        HStack(spacing: 4) {
                            Button("terms_of_service") { }
                            Text("•").foregroundStyle(.tertiary)
                            Button("privacy_policy") { }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") {
                        dismiss()
                    }
                }
            }
            .alert(isPresented: .constant(subscriptionManager.errorMessage != nil)) {
                Alert(
                    title: Text("error"),
                    message: Text(subscriptionManager.errorMessage ?? ""),
                    dismissButton: .default(Text("ok")) {
                        subscriptionManager.errorMessage = nil
                    }
                )
            }
        }
    }

    // Price display from StoreKit or default
    private var priceString: String {
        // Use StoreKit product price if available
        if let product = subscriptionManager.monthlyProduct {
            return product.displayPrice
        }

        // Default fallback (will show $2 price once configured in App Store Connect)
        let locale = Locale.current
        let regionCode = locale.region?.identifier ?? "US"

        if regionCode == "KR" {
            return "₩2,900"
        } else if regionCode == "JP" {
            return "¥300"
        } else {
            return "$2.00" // Default $2 price
        }
    }
}

struct FeatureRow: View {
    let feature: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: featureIcon(for: feature))
                    .foregroundStyle(.green)
                    .font(.system(size: 20))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(feature))
                    .font(.body)
                    .fontWeight(.medium)
                Text(LocalizedStringKey("\(feature)_desc"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }

    private func featureIcon(for feature: String) -> String {
        switch feature {
        case "auto_sync":
            return "arrow.triangle.2.circlepath"
        case "cloud_backup":
            return "cloud.fill"
        case "device_recovery":
            return "arrow.counterclockwise"
        case "multi_device_3_5":
            return "apps.iphone"
        case "security_alerts":
            return "bell.badge.fill"
        default:
            return "checkmark.circle.fill"
        }
    }
}

#Preview {
    SubscriptionView()
}
