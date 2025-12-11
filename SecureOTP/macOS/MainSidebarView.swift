import SwiftUI

#if os(macOS)
struct MainSidebarView: View {
    @State private var selection: SidebarItem = .otp

    enum SidebarItem: String, CaseIterable {
        case account = "Account"
        case otp = "OTP Services"

        var icon: String {
            switch self {
            case .account: return "person.circle.fill"
            case .otp: return "shield.lefthalf.filled"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, id: \.self, selection: $selection) { item in
                Label(item.rawValue, systemImage: item.icon)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            switch selection {
            case .account:
                AccountView()
            case .otp:
                OTPListView()
            }
        }
    }
}
#endif
