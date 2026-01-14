import SwiftUI

struct AccountSelectionView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Current Account
                if let user = authManager.currentUser {
                    Section {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(providerColor(user.provider))
                                    .frame(width: 60, height: 60)
                                Image(systemName: providerIcon(user.provider))
                                    .font(.system(size: 30))
                                    .foregroundStyle(.white)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.name)
                                    .font(.headline)
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.caption)
                                    Text(providerDisplayName(user.provider))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    } header: {
                        Text(LocalizedStringKey("current_account"))
                    } footer: {
                        Text(LocalizedStringKey("current_account_footer"))
                            .font(.caption)
                    }

                    // Account Actions
                    Section {
                        Button(role: .destructive, action: {
                            authManager.signOut()
                            dismiss()
                        }) {
                            HStack {
                                Spacer()
                                if authManager.isLoading {
                                    ProgressView()
                                } else {
                                    Label("sign_out_and_switch", systemImage: "arrow.triangle.2.circlepath")
                                }
                                Spacer()
                            }
                        }
                        .disabled(authManager.isLoading)
                    } footer: {
                        Text(LocalizedStringKey("sign_out_to_switch_info"))
                            .font(.caption)
                    }
                } else {
                    // Not signed in
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "person.crop.circle.badge.questionmark")
                                .font(.system(size: 60))
                                .foregroundStyle(.secondary)

                            Text("not_signed_in")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Text("sign_in_to_sync_info")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)

                            Button(action: {
                                dismiss()
                                // User will be redirected to SignInView automatically
                            }) {
                                Text("go_to_sign_in")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 20)
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("account_management")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func providerIcon(_ provider: String) -> String {
        switch provider {
        case "apple": return "apple.logo"
        case "google": return "g.circle.fill"
        case "email": return "envelope.fill"
        default: return "person.fill"
        }
    }

    private func providerColor(_ provider: String) -> LinearGradient {
        switch provider {
        case "apple":
            return LinearGradient(colors: [.black, .gray], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "google":
            return LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "email":
            return LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            return LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private func providerDisplayName(_ provider: String) -> String {
        switch provider {
        case "apple": return "Apple"
        case "google": return "Google"
        case "email": return "Email"
        default: return "Unknown"
        }
    }
}

#Preview {
    AccountSelectionView()
}
