import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            OTPListView()
                .tabItem {
                    Label("OTP", systemImage: "shield.lefthalf.filled")
                }
                .tag(0)

            AccountView()
                .tabItem {
                    Label("Account", systemImage: "person.circle.fill")
                }
                .tag(1)
        }
    }
}
