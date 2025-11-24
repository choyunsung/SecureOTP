//
//  AuthenticatorView.swift
//  SecureSignInClient
//
//  사용자 본인 계정 인증 화면
//

import SwiftUI

struct AuthenticatorView: View {
    @ObservedObject private var authManager = AuthenticationManager.shared

    var body: some View {
        #if os(iOS)
        iOSView
        #elseif os(macOS)
        macOSView
        #elseif os(watchOS)
        watchOSView
        #endif
    }

    // MARK: - iOS View

    #if os(iOS)
    private var iOSView: some View {
        NavigationStack {
            Group {
                if let account = authManager.currentUser {
                    authenticatedView(account: account)
                } else {
                    SignInView()
                }
            }
            .navigationTitle("My Account")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    #endif

    // MARK: - macOS View

    #if os(macOS)
    private var macOSView: some View {
        VStack {
            if let account = authManager.currentUser {
                authenticatedView(account: account)
            } else {
                SignInView()
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }
    #endif

    // MARK: - watchOS View

    #if os(watchOS)
    private var watchOSView: some View {
        ScrollView {
            if let account = authManager.currentUser {
                watchAuthenticatedView(account: account)
            } else {
                watchSetupView
            }
        }
        .navigationTitle("Account")
    }
    #endif

    // MARK: - Common Views

    private func authenticatedView(account: UserAccount) -> some View {
        VStack(spacing: 24) {
            // Profile Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "person.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }

            // User Info
            VStack(spacing: 8) {
                Text(account.username)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(account.email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    // Provider Badge
                    HStack(spacing: 4) {
                        Image(systemName: account.providerIcon)
                            .font(.caption)
                        Text(account.provider.rawValue)
                            .font(.caption)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(12)

                    // Verified Badge
                    if account.isVerified {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill")
                            Text("Verified")
                                .font(.caption)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .cornerRadius(12)
                    }
                }
            }

            Divider()
                .padding(.horizontal)

            // Account Info
            VStack(alignment: .leading, spacing: 16) {
                infoRow(icon: "calendar", title: "Created", value: formatDate(account.createdAt))

                if let lastVerified = account.lastVerified {
                    infoRow(icon: "clock.fill", title: "Last Verified", value: formatDate(lastVerified))
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            // Logout Button
            Button(action: logout) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Sign Out")
                }
                #if os(iOS)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.1))
                .foregroundColor(.red)
                .cornerRadius(12)
                #endif
            }
            #if os(iOS)
            .padding(.horizontal, 24)
            #endif
        }
        .padding(.vertical)
    }

    // MARK: - watchOS Specific Views

    #if os(watchOS)
    private func watchAuthenticatedView(account: UserAccount) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 60, height: 60)

                Image(systemName: "person.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
            }

            Text(account.username)
                .font(.headline)

            Text(account.email)
                .font(.caption2)
                .foregroundColor(.secondary)

            if account.isVerified {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    Text("Verified")
                        .font(.caption2)
                }
            }

            Button(action: logout) {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
            .foregroundColor(.red)
        }
        .padding()
    }

    private var watchSetupView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 40))
                .foregroundColor(.blue)

            Text("Setup on iPhone")
                .font(.headline)

            Text("Create your account on iPhone or Mac")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    #endif

    // MARK: - Helper Views

    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.body)
            }

            Spacer()
        }
    }

    // MARK: - Helper Functions

    private func logout() {
        authManager.signOut()
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
