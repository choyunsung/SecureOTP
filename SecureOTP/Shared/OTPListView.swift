import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

struct OTPListView: View {
    @State private var accounts: [OTPAccount] = []
    @State private var showAddAccount = false
    @State private var editingAccount: OTPAccount?
    @State private var isLoading = false
    @State private var isSyncing = false

    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    private let api = APIService.shared

    var body: some View {
        #if os(iOS)
        NavigationStack {
            mainContent
        }
        #elseif os(macOS)
        VStack(spacing: 0) {
            // Custom header for macOS
            HStack {
                Text("SecureOTP")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                if isSyncing {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 28, height: 28)
                } else {
                    Button(action: {
                        AddOTPWindowController.shared.showWindow { account in
                            addAccount(account)
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    .help("Add OTP Account")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Main content
            Group {
                if isLoading && accounts.isEmpty {
                    Spacer()
                    ProgressView("Loading...")
                    Spacer()
                } else if accounts.isEmpty {
                    emptyView
                } else {
                    listView
                }
            }
        }
        .frame(minWidth: 320, minHeight: 400)
        .onAppear { loadAccounts() }
        #else
        mainContent
        #endif
    }

    #if !os(macOS)
    private var mainContent: some View {
        Group {
            if isLoading && accounts.isEmpty {
                ProgressView("Loading...")
            } else if accounts.isEmpty {
                emptyView
            } else {
                listView
            }
        }
        .navigationTitle("otp_services")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if isSyncing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button(action: {
                        #if targetEnvironment(macCatalyst)
                        CatalystWindowController.shared.showAddOTPWindow { account in
                            addAccount(account)
                        }
                        #else
                        showAddAccount = true
                        #endif
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showAddAccount) {
            #if os(iOS)
            AddOTPView { account in
                addAccount(account)
            }
            #endif
        }
        .sheet(item: $editingAccount) { account in
            EditOTPView(account: account) { newIssuer, newAccountName in
                updateAccount(account, newIssuer: newIssuer, newAccountName: newAccountName)
            }
        }
        .onAppear {
            loadAccounts()
            // Auto-sync to Watch on app start
            #if !os(watchOS)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.saveAccountsLocally()
            }
            #endif
        }
        .refreshable { await syncAccounts() }
    }
    #endif

    private var emptyView: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 44))
                    .foregroundStyle(.blue)
            }
            Text("no_otp_services")
                .font(.title2)
                .fontWeight(.bold)
            Text("tap_to_add")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var listView: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(accounts) { account in
                        OTPRowView(account: account, onDelete: {
                            deleteAccount(account)
                        }, onEdit: {
                            editingAccount = account
                        })
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }

            // Ad Banner for free users
            AdBannerView()
        }
    }

    private func loadAccounts() {
        // Load local first
        if let data = UserDefaults.standard.data(forKey: "otp_accounts"),
           let decoded = try? JSONDecoder().decode([OTPAccount].self, from: data) {
            accounts = decoded
        }

        // Then sync with server
        Task {
            await syncAccounts()
        }
    }

    private func syncAccounts() async {
        guard !isSyncing else { return }

        // Check if user has Pro subscription
        // If not Pro, silently skip sync (no popup)
        guard subscriptionManager.canSync else {
            return
        }

        await MainActor.run { isSyncing = true }

        do {
            let serverAccounts = try await api.getOTPAccounts()
            let otpAccounts = serverAccounts.map { $0.toOTPAccount() }

            await MainActor.run {
                // Merge local and server accounts
                var merged = accounts
                for serverAccount in otpAccounts {
                    if !merged.contains(where: { $0.secret == serverAccount.secret && $0.accountName == serverAccount.accountName }) {
                        merged.append(serverAccount)
                    }
                }
                accounts = merged
                saveAccountsLocally()
                isSyncing = false
            }

            // Sync local accounts to server
            if !accounts.isEmpty {
                _ = try await api.syncOTPAccounts(accounts)
            }
        } catch {
            await MainActor.run {
                isSyncing = false
            }
            print("Sync error: \(error)")
        }
    }

    private func addAccount(_ account: OTPAccount) {
        accounts.append(account)
        saveAccountsLocally()

        // Sync to server
        Task {
            do {
                _ = try await api.addOTPAccount(account)
            } catch {
                print("Failed to sync account: \(error)")
            }
        }
    }

    private func updateAccount(_ account: OTPAccount, newIssuer: String, newAccountName: String) {
        // Create updated account
        let updatedAccount = OTPAccount(
            id: account.id,
            issuer: newIssuer,
            accountName: newAccountName,
            secret: account.secret
        )

        // Update in local array
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = updatedAccount
            saveAccountsLocally()

            // Sync to server
            Task {
                do {
                    // Delete old and add new (as update)
                    try await api.deleteOTPAccount(id: account.id.uuidString)
                    _ = try await api.addOTPAccount(updatedAccount)
                } catch {
                    print("Failed to update account on server: \(error)")
                }
            }
        }
    }

    private func deleteAccount(_ account: OTPAccount) {
        accounts.removeAll { $0.id == account.id }
        saveAccountsLocally()

        // Delete from server
        Task {
            do {
                try await api.deleteOTPAccount(id: account.id.uuidString)
            } catch {
                print("Failed to delete from server: \(error)")
            }
        }
    }

    private func saveAccountsLocally() {
        // Save to shared App Group container (accessible by Watch app)
        SharedUserDefaults.shared.saveOTPAccounts(accounts)

        // Also keep in local UserDefaults for backward compatibility
        if let encoded = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(encoded, forKey: "otp_accounts")

            // Still try WatchConnectivity as fallback
            #if !os(watchOS) && canImport(WatchConnectivity)
            syncToWatch(encoded)
            #endif
        }
    }

    #if !os(watchOS) && canImport(WatchConnectivity)
    private func syncToWatch(_ accountsData: Data) {
        guard WCSession.isSupported() else { return }

        let session = WCSession.default

        // Wait for activation if needed
        if session.activationState == .notActivated {
            print("📱 Waiting for WCSession activation...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [self] in
                self.syncToWatch(accountsData)
            }
            return
        }

        guard session.activationState == .activated else {
            print("⚠️ WCSession not ready, will retry...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
                self.syncToWatch(accountsData)
            }
            return
        }

        let message = ["accounts": accountsData]

        // Try immediate send if reachable
        if session.isReachable {
            print("📱 iPhone is reachable, sending immediate message")
            session.sendMessage(message, replyHandler: nil) { error in
                print("❌ Failed to send to Watch: \(error.localizedDescription)")
            }
        } else {
            print("📱 iPhone not reachable, using background sync")
        }

        // Always update context for background sync
        // Try updateApplicationContext first
        do {
            try session.updateApplicationContext(message)
            print("✅ Synced \(accounts.count) accounts to Apple Watch via context")
        } catch {
            print("⚠️ updateApplicationContext failed: \(error.localizedDescription)")
            // Fallback: use transferUserInfo which doesn't check isWatchAppInstalled
            session.transferUserInfo(message)
            print("📤 Sent \(accounts.count) accounts via transferUserInfo (fallback)")
        }
    }
    #endif
}

// MARK: - Edit OTP View

struct EditOTPView: View {
    let account: OTPAccount
    var onSave: ((String, String) -> Void)?
    var onCancel: (() -> Void)?

    @State private var issuer: String
    @State private var accountName: String
    @State private var showSecret = false
    @State private var showCopied = false

    @Environment(\.dismiss) private var dismiss

    init(account: OTPAccount, onSave: ((String, String) -> Void)? = nil, onCancel: (() -> Void)? = nil) {
        self.account = account
        self.onSave = onSave
        self.onCancel = onCancel
        _issuer = State(initialValue: account.issuer)
        _accountName = State(initialValue: account.accountName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("account_information") {
                    TextField("issuer", text: $issuer)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif

                    TextField("account_name", text: $accountName)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                }

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("secret_key")
                                .font(.headline)
                            Spacer()
                            Button(action: {
                                withAnimation {
                                    showSecret.toggle()
                                }
                            }) {
                                Image(systemName: showSecret ? "eye.slash.fill" : "eye.fill")
                                    .foregroundStyle(.blue)
                            }
                        }

                        if showSecret {
                            HStack {
                                Text(formatSecret(account.secret))
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Button(action: {
                                    copyToClipboard(account.secret)
                                    showCopiedFeedback()
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .padding(.vertical, 8)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                } header: {
                    Text(LocalizedStringKey("secret_key"))
                } footer: {
                    Text(LocalizedStringKey("keep_secret_safe"))
                        .font(.caption)
                }
            }
            .navigationTitle("edit_otp_account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") {
                        if let onCancel = onCancel {
                            onCancel()
                        } else {
                            dismiss()
                        }
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("save") {
                        if let onSave = onSave {
                            onSave(issuer.trimmingCharacters(in: .whitespaces),
                                   accountName.trimmingCharacters(in: .whitespaces))
                        }
                        dismiss()
                    }
                    .disabled(accountName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .overlay(alignment: .center) {
                if showCopied {
                    Text("secret_key_copied")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.75))
                        .clipShape(Capsule())
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showCopied)
        }
    }

    private func formatSecret(_ secret: String) -> String {
        // Format secret in groups of 4 for readability
        var formatted = ""
        for (index, char) in secret.enumerated() {
            if index > 0 && index % 4 == 0 {
                formatted += " "
            }
            formatted.append(char)
        }
        return formatted
    }

    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }

    private func showCopiedFeedback() {
        showCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showCopied = false
        }
    }
}
