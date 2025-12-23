import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var dragOffset: CGFloat = 0

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
        .gesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onChanged { value in
                    dragOffset = value.translation.width
                }
                .onEnded { value in
                    let threshold: CGFloat = 50

                    if value.translation.width < -threshold && selectedTab == 0 {
                        // Swipe left: OTP -> Account
                        withAnimation {
                            selectedTab = 1
                        }
                    } else if value.translation.width > threshold && selectedTab == 1 {
                        // Swipe right: Account -> OTP
                        withAnimation {
                            selectedTab = 0
                        }
                    }

                    dragOffset = 0
                }
        )
    }
}
