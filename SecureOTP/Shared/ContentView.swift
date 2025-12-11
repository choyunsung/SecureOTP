import SwiftUI

struct ContentView: View {
    @ObservedObject private var authManager = AuthManager.shared

    var body: some View {
        Group {
            if authManager.isLoggedIn {
                #if os(iOS)
                MainTabView()
                #else
                MainSidebarView()
                #endif
            } else {
                SignInView()
            }
        }
        .animation(.easeInOut, value: authManager.isLoggedIn)
    }
}
