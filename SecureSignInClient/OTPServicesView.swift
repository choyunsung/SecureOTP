//
//  OTPServicesView.swift
//  SecureSignInClient
//
//  등록된 OTP 서비스 목록 화면
//

import SwiftUI

struct OTPServicesView: View {
    @State private var accounts: [OTPAccount] = []
    @State private var isAddingAccount = false

    var body: some View {
        #if os(watchOS)
        watchOSView
        #elseif os(iOS)
        iOSView
        #else
        macOSView
        #endif
    }

    // MARK: - iOS View

    #if os(iOS)
    private var iOSView: some View {
        NavigationStack {
            Group {
                if accounts.isEmpty {
                    emptyStateView
                } else {
                    accountListView
                }
            }
            .navigationTitle("OTP Services")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { isAddingAccount = true }) {
                        Image(systemName: "plus")
                            .font(.title3)
                    }
                }
            }
            .onAppear(perform: loadAccounts)
            .sheet(isPresented: $isAddingAccount, onDismiss: saveAccounts) {
                AddAccountView(onAdd: addAccount)
            }
        }
    }
    #endif

    // MARK: - macOS View

    #if os(macOS)
    private var macOSView: some View {
        Group {
            if accounts.isEmpty {
                emptyStateView
            } else {
                accountListView
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { isAddingAccount = true }) {
                    Label("Add Service", systemImage: "plus")
                }
            }
        }
        .onAppear(perform: loadAccounts)
        .sheet(isPresented: $isAddingAccount, onDismiss: saveAccounts) {
            AddAccountView(onAdd: addAccount)
        }
        .frame(minWidth: 400, minHeight: 200)
    }
    #endif

    // MARK: - watchOS View

    #if os(watchOS)
    private var watchOSView: some View {
        List {
            if accounts.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No Services")
                        .font(.headline)
                }
                .listRowBackground(Color.clear)
            } else {
                ForEach(accounts) { account in
                    WatchOTPRowView(account: account)
                }
            }
        }
        .navigationTitle("OTP")
        .onAppear(perform: loadAccounts)
    }
    #endif

    // MARK: - Common Views

    private var accountListView: some View {
        List {
            ForEach(accounts) { account in
                OTPAccountRowView(account: account)
                    #if os(iOS)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    #endif
            }
            .onDelete(perform: deleteAccount)
        }
        #if os(iOS)
        .listStyle(.plain)
        .background(Color(.systemGroupedBackground))
        #endif
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "shield.lefthalf.filled")
                #if os(macOS)
                .font(.system(size: 60))
                #else
                .font(.system(size: 50))
                #endif
                .foregroundColor(.secondary)

            Text("No OTP Services")
                .font(.title2)
                .fontWeight(.bold)

            #if os(macOS)
            Text("Click the '+' button to add a new OTP service.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            #else
            Text("Tap the '+' button to add a new OTP service like Google, GitHub, or other 2FA services.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Data Management

    private func loadAccounts() {
        self.accounts = KeychainHelper.shared.loadAccounts()
    }

    private func saveAccounts() {
        KeychainHelper.shared.saveAccounts(accounts)
    }

    private func addAccount(_ account: OTPAccount) {
        accounts.append(account)
        // The save operation will be called when the sheet dismisses.
    }

    private func deleteAccount(at offsets: IndexSet) {
        accounts.remove(atOffsets: offsets)
        saveAccounts()
    }
}
