import SwiftUI

#if os(watchOS)
@main
struct SecureOTPWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchContentView()
        }
    }
}
#endif
