import SwiftUI

struct AppInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // App Icon & Name
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 22)
                                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 100, height: 100)
                                Image(systemName: "shield.lefthalf.filled")
                                    .font(.system(size: 50))
                                    .foregroundStyle(.white)
                            }

                            VStack(spacing: 4) {
                                Text("Secure OTP")
                                    .font(.title2)
                                    .fontWeight(.bold)

                                Text(versionBuildString)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 20)
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)

                // Company Info
                Section("company_info") {
                    HStack {
                        Label("company", systemImage: "building.2")
                        Spacer()
                        Text("Quetta Soft")
                            .foregroundStyle(.secondary)
                    }

                    Link(destination: URL(string: "https://quettasoft.com")!) {
                        HStack {
                            Label("website", systemImage: "globe")
                            Spacer()
                            Text("quettasoft.com")
                                .foregroundStyle(.secondary)
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                // Legal
                Section("legal") {
                    Button(action: {}) {
                        HStack {
                            Label("terms_of_service", systemImage: "doc.text")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)

                    Button(action: {}) {
                        HStack {
                            Label("privacy_policy", systemImage: "hand.raised")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)

                    Button(action: {}) {
                        HStack {
                            Label("open_source_licenses", systemImage: "doc.on.doc")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                }

                // Copyright
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Text("© 2024 Quetta Soft")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text("Made with ❤️ in Korea")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("app_info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var versionBuildString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    AppInfoView()
}
