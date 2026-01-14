import SwiftUI

struct AdBannerView: View {
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showSubscription = false

    var body: some View {
        if !subscriptionManager.isPro {
            VStack(spacing: 0) {
                Divider()

                Button(action: {
                    showSubscription = true
                }) {
                    HStack(spacing: 12) {
                    // Ad Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 50, height: 50)
                        Image(systemName: "sparkles")
                            .foregroundStyle(.white)
                            .font(.system(size: 24))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text("Pro")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                                )
                                .clipShape(Capsule())

                            Text("AD")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                        }

                        Text("remove_ads_with_pro")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)

                        Text("only_2900_per_month")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .background(Color.gray.opacity(0.15))
            }
            .sheet(isPresented: $showSubscription) {
                SubscriptionView()
            }
        }
    }
}

#Preview {
    VStack {
        Spacer()
        AdBannerView()
    }
}
