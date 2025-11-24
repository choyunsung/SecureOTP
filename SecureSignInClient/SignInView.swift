//
//  SignInView.swift
//  SecureSignInClient
//
//  Apple & Google Sign In 화면
//

import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @ObservedObject private var authManager = AuthenticationManager.shared
    @State private var showManualSignIn = false

    var body: some View {
        ZStack {
            // Background gradient
            #if os(iOS)
            LinearGradient(
                colors: [Color.blue.opacity(0.05), Color.purple.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            #endif

            VStack(spacing: 40) {
                Spacer()

                // Logo & Title
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                            .shadow(color: .blue.opacity(0.3), radius: 20, x: 0, y: 10)

                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                    }

                    Text("Secure OTP")
                        .font(.system(size: 36, weight: .bold))

                    Text("Sign in to continue")
                        .font(.body)
                        .foregroundColor(.secondary)
                }

                Spacer()

            // Sign In Buttons
            VStack(spacing: 14) {
                // Apple Sign In
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    handleAppleSignIn(result)
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 56)
                .cornerRadius(14)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)

                // Google Sign In
                Button(action: {
                    Task {
                        await authManager.signInWithGoogle()
                    }
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 24, height: 24)

                            Text("G")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color(red: 66/255, green: 133/255, blue: 244/255))
                        }

                        Text("Continue with Google")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
                }

                // Manual Sign In
                Button(action: {
                    showManualSignIn = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.blue)
                        Text("Continue with Email")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    #if os(iOS)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(.systemGray6))
                    )
                    #else
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.gray.opacity(0.1))
                    )
                    #endif
                    .foregroundColor(.primary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                }
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()

            // Terms & Privacy
            VStack(spacing: 8) {
                Text("By continuing, you agree to our")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Button("Terms of Service") {}
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("and")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("Privacy Policy") {}
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showManualSignIn) {
            ManualSignInView()
        }
    }

    @Environment(\.colorScheme) var colorScheme

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            authManager.handleAppleSignInResult(authorization: authorization)
        case .failure(let error):
            print("Apple Sign In failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Manual Sign In View

struct ManualSignInView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var authManager = AuthenticationManager.shared

    @State private var username = ""
    @State private var email = ""

    var body: some View {
        NavigationStack {
            ZStack {
                #if os(iOS)
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                #endif

                VStack(spacing: 24) {
                    // Header Icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)

                        Image(systemName: "person.crop.circle.fill.badge.plus")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 40)

                    Text("Create Account")
                        .font(.title2)
                        .fontWeight(.bold)

                    // Form Fields
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Username")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)

                            TextField("Enter your username", text: $username)
                                #if os(iOS)
                                .textContentType(.username)
                                .autocapitalization(.words)
                                #endif
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        #if os(iOS)
                                        .fill(Color(.systemBackground))
                                        #else
                                        .fill(Color.white)
                                        #endif
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)

                            TextField("Enter your email", text: $email)
                                #if os(iOS)
                                .textContentType(.emailAddress)
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                                #endif
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        #if os(iOS)
                                        .fill(Color(.systemBackground))
                                        #else
                                        .fill(Color.white)
                                        #endif
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 32)

                    // Create Button
                    Button(action: createAccount) {
                        Text("Create Account")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    colors: username.isEmpty || email.isEmpty ?
                                        [.gray, .gray] :
                                        [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(14)
                            .shadow(color: .blue.opacity(username.isEmpty || email.isEmpty ? 0 : 0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(username.isEmpty || email.isEmpty)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)

                    Spacer()
                }
            }
            .navigationTitle("Sign Up")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func createAccount() {
        authManager.createManualAccount(username: username, email: email)
        dismiss()
    }
}
