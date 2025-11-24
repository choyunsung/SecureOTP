import SwiftUI

@main
struct SecureSignInClientApp: App {
    #if os(macOS)
    // AppDelegate는 창이 닫힐 때 앱이 종료되는 동작을 관리합니다.
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #elseif os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            #if os(macOS)
            // NavigationView를 사용하여 타이틀과 툴바를 제공합니다.
            NavigationView {
                ContentView()
            }
            #elseif os(iOS)
            // iOS uses NavigationStack for modern navigation
            NavigationStack {
                ContentView()
            }
            #elseif os(watchOS)
            // watchOS uses simpler navigation
            NavigationView {
                ContentView()
            }
            #endif
        }
    }
}