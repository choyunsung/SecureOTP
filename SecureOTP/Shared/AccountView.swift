import SwiftUI
#if canImport(LocalAuthentication)
import LocalAuthentication
#endif

struct AccountView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @ObservedObject private var deviceManager = DeviceManager.shared
    @AppStorage("app_language") private var selectedLanguage = "en"
    @AppStorage("app_theme") private var selectedTheme = "system"
    @AppStorage("use_biometric") private var useBiometric = false

    @State private var showLanguageSheet = false
    @State private var showSubscriptionSheet = false
    @State private var showDeviceListSheet = false
    @State private var showAppInfoSheet = false
    @State private var showAccountSelectionSheet = false
    @State private var biometricType: BiometricType = .none

    enum BiometricType {
        case faceID, touchID, none

        var displayName: String {
            switch self {
            case .faceID: return "Face ID"
            case .touchID: return "Touch ID"
            case .none: return "Biometric"
            }
        }
    }

    var body: some View {
        #if os(iOS)
        NavigationStack {
            accountContent
                .navigationTitle("account")
        }
        #else
        accountContent
            .navigationTitle("account")
        #endif
    }

    private var accountContent: some View {
        Form {
            // Profile Section
            Section {
                Button(action: { showAccountSelectionSheet = true }) {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 60, height: 60)
                            Image(systemName: "person.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            if let user = authManager.currentUser {
                                Text(user.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("guest_user")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("not_signed_in")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 8)
            }

            // Settings Section (구독 + 동기화 + 설정)
            Section("settings") {
                // Subscription
                Button(action: { showSubscriptionSheet = true }) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(subscriptionManager.isPro ? LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(colors: [.gray], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 40, height: 40)
                            Image(systemName: subscriptionManager.isPro ? "crown.fill" : "crown")
                                .foregroundStyle(.white)
                                .font(.system(size: 20))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(subscriptionManager.isPro ? "pro_plan" : "free_plan")
                                .font(.body)
                                .foregroundStyle(.primary)
                            if subscriptionManager.isPro {
                                Text("\(regionalPrice) / monthly")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("upgrade_to_pro")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                        }

                        Spacer()

                        if subscriptionManager.isPro {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .foregroundStyle(.primary)

                // Sync Devices
                Button(action: { showDeviceListSheet = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "laptopcomputer.and.iphone")
                            .foregroundStyle(.blue)
                            .font(.system(size: 20))
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("sync_devices")
                                .font(.body)
                                .foregroundStyle(.primary)

                            if subscriptionManager.isPro {
                                Text("\(deviceManager.devices.count) devices_connected")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                HStack(spacing: 4) {
                                    Image(systemName: "lock.fill")
                                        .font(.caption2)
                                    Text("pro_required")
                                }
                                .font(.caption)
                                .foregroundStyle(.orange)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.primary)
                // Language
                Button(action: { showLanguageSheet = true }) {
                    HStack {
                        Label("language", systemImage: "globe")
                        Spacer()
                        Text(languageDisplayName(selectedLanguage))
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.primary)

                // Theme
                Picker(selection: $selectedTheme) {
                    Label("system", systemImage: "circle.lefthalf.filled").tag("system")
                    Label("light", systemImage: "sun.max").tag("light")
                    Label("dark", systemImage: "moon").tag("dark")
                } label: {
                    Label("theme", systemImage: "paintbrush")
                }

                // Biometric Authentication
                NavigationLink(destination: BiometricSettingsView()) {
                    HStack(spacing: 12) {
                        Image(systemName: biometricIconName)
                            .foregroundStyle(.blue)
                            .font(.system(size: 20))
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(biometricDisplayName)
                                .font(.body)
                                .foregroundStyle(.primary)

                            if BiometricAuthManager.shared.biometricType != .none {
                                Text(BiometricAuthManager.shared.isBiometricEnabled ? "enabled" : "disabled")
                                    .font(.caption)
                                    .foregroundStyle(BiometricAuthManager.shared.isBiometricEnabled ? .green : .secondary)
                            } else {
                                Text("not_available")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }

                        Spacer()

                        if BiometricAuthManager.shared.isBiometricEnabled {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .foregroundStyle(.primary)
            }

            // About Section
            Section("about") {
                Button(action: { showAppInfoSheet = true }) {
                    HStack {
                        Label("app_info", systemImage: "info.circle")
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(appVersion)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Quetta Soft")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.primary)
            }

            // Sign Out Section
            Section {
                Button(role: .destructive, action: { authManager.signOut() }) {
                    HStack {
                        Spacer()
                        Label("sign_out", systemImage: "rectangle.portrait.and.arrow.right")
                        Spacer()
                    }
                }
            }
        }
        .sheet(isPresented: $showAccountSelectionSheet) {
            AccountSelectionView()
        }
        .sheet(isPresented: $showLanguageSheet) {
            LanguageSelectionView(selectedLanguage: $selectedLanguage)
        }
        .sheet(isPresented: $showSubscriptionSheet) {
            SubscriptionView()
        }
        .sheet(isPresented: $showDeviceListSheet) {
            DeviceListView()
        }
        .sheet(isPresented: $showAppInfoSheet) {
            AppInfoView()
        }
        .onAppear {
            checkBiometricType()
            deviceManager.loadDevices()
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private var regionalPrice: String {
        let locale = Locale.current
        let regionCode = locale.region?.identifier ?? "US"

        if regionCode == "KR" {
            return "₩2,900"
        } else if regionCode == "US" {
            return "$1.99"
        } else if regionCode == "JP" {
            return "¥300"
        } else {
            return "$1.99"
        }
    }

    private var biometricIconName: String {
        switch BiometricAuthManager.shared.biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .opticID:
            return "opticid"
        case .none:
            return "lock.shield"
        }
    }

    private var biometricDisplayName: String {
        switch BiometricAuthManager.shared.biometricType {
        case .faceID:
            return "Face ID & Passcode"
        case .touchID:
            return "Touch ID & Passcode"
        case .opticID:
            return "Optic ID & Passcode"
        case .none:
            return "Biometric Authentication"
        }
    }

    private func languageDisplayName(_ code: String) -> String {
        switch code {
        case "en": return "English"
        case "ko": return "한국어"
        case "ja": return "日本語"
        case "zh": return "中文"
        default: return "English"
        }
    }

    private func checkBiometricType() {
        #if canImport(LocalAuthentication)
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID:
                biometricType = .faceID
            case .touchID:
                biometricType = .touchID
            default:
                biometricType = .none
            }
        }
        #endif
    }
}

// MARK: - Language Selection View

struct LanguageSelectionView: View {
    @Binding var selectedLanguage: String
    @Environment(\.dismiss) private var dismiss

    let languages = [
        ("en", "English"),
        ("ko", "한국어"),
        ("ja", "日本語"),
        ("zh", "中文")
    ]

    var body: some View {
        NavigationStack {
            List(languages, id: \.0) { code, name in
                Button(action: {
                    selectedLanguage = code
                    dismiss()
                }) {
                    HStack {
                        Text(name)
                            .foregroundStyle(.primary)
                        Spacer()
                        if selectedLanguage == code {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            .navigationTitle("language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
