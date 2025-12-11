import SwiftUI

struct AccountView: View {
    @ObservedObject private var authManager = AuthManager.shared

    var body: some View {
        #if os(iOS)
        NavigationStack {
            accountContent
                .navigationTitle("Account")
        }
        #else
        accountContent
        #endif
    }

    private var accountContent: some View {
        VStack(spacing: 24) {
            Spacer()

            // Profile
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 100, height: 100)
                Image(systemName: "person.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.white)
            }

            if let user = authManager.currentUser {
                VStack(spacing: 8) {
                    Text(user.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(user.email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(action: { authManager.signOut() }) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Sign Out")
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.red.opacity(0.1))
                .foregroundStyle(.red)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}
