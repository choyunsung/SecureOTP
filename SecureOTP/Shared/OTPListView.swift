import SwiftUI

struct OTPListView: View {
    @State private var accounts: [OTPAccount] = []
    @State private var showAddAccount = false
    @State private var isLoading = false
    @State private var isSyncing = false

    private let api = APIService.shared

    var body: some View {
        #if os(iOS)
        NavigationStack {
            mainContent
        }
        #else
        mainContent
        #endif
    }

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
        .navigationTitle("OTP Services")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if isSyncing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button(action: {
                        #if os(macOS)
                        AddOTPWindowController.shared.showWindow { account in
                            addAccount(account)
                        }
                        #elseif targetEnvironment(macCatalyst)
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
        #if os(iOS)
        .sheet(isPresented: $showAddAccount) {
            AddOTPView { account in
                addAccount(account)
            }
        }
        #endif
        .onAppear { loadAccounts() }
        .refreshable { await syncAccounts() }
    }

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
            Text("No OTP Services")
                .font(.title2)
                .fontWeight(.bold)
            Text("Tap '+' to add a service")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var listView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(accounts) { account in
                    OTPRowView(account: account, onDelete: {
                        deleteAccount(account)
                    })
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
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
        if let encoded = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(encoded, forKey: "otp_accounts")
        }
    }
}
