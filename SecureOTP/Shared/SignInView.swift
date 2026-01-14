import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @State private var showEmailSignIn = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Logo
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

                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 48))
                    .foregroundStyle(.white)
            }

            // Title
            VStack(spacing: 8) {
                Text("Secure OTP")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Sign in to continue")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    if case .success(let auth) = result {
                        authManager.signInWithApple(authorization: auth)
                    }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Button(action: { authManager.signInWithGoogle() }) {
                    HStack {
                        Image(systemName: "g.circle.fill")
                            .foregroundStyle(.red)
                        Text("Continue with Google")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    #if os(iOS)
                    .background(Color.gray.opacity(0.15))
                    #else
                    .background(Color.gray.opacity(0.2))
                    #endif
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button(action: { showEmailSignIn = true }) {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundStyle(.blue)
                        Text("Continue with Email")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    #if os(iOS)
                    .background(Color.gray.opacity(0.15))
                    #else
                    .background(Color.gray.opacity(0.2))
                    #endif
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

            // Terms
            Text("By continuing, you agree to our Terms and Privacy Policy")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 32)
        }
        .padding(.horizontal, 24)
        .sheet(isPresented: $showEmailSignIn) {
            EmailSignInView()
        }
    }
}

struct EmailSignInView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var authManager = AuthManager.shared
    @State private var name = ""
    @State private var email = ""

    var body: some View {
        #if os(iOS)
        NavigationStack {
            formContent
                .navigationTitle("Sign In")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
        .onChange(of: authManager.isLoggedIn) { _, isLoggedIn in
            if isLoggedIn {
                dismiss()
            }
        }
        #else
        VStack {
            formContent
        }
        .frame(width: 350, height: 350)
        .padding()
        .onChange(of: authManager.isLoggedIn) { _, isLoggedIn in
            if isLoggedIn {
                dismiss()
            }
        }
        #endif
    }

    private var formContent: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 80, height: 80)
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }
            .padding(.top, 20)

            VStack(spacing: 16) {
                TextField("Name", text: $name)
                    .textFieldStyle(.plain)
                    .padding()
                    #if os(iOS)
                    .background(Color.gray.opacity(0.15))
                    #else
                    .background(Color.gray.opacity(0.2))
                    #endif
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                TextField("Email", text: $email)
                    .textFieldStyle(.plain)
                    #if os(iOS)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    #endif
                    .padding()
                    #if os(iOS)
                    .background(Color.gray.opacity(0.15))
                    #else
                    .background(Color.gray.opacity(0.2))
                    #endif
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button(action: {
                authManager.signInWithEmail(name: name, email: email)
            }) {
                Text("Sign In")
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        (!name.isEmpty && !email.isEmpty)
                            ? LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(name.isEmpty || email.isEmpty)

            #if os(macOS)
            Button("Cancel") { dismiss() }
            #endif

            Spacer()
        }
        .padding(.horizontal, 24)
    }
}
