import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

// MARK: - Watch Session Delegate

#if os(iOS) && canImport(WatchConnectivity)
class WatchSessionDelegateShared: NSObject, WCSessionDelegate {
    static let shared = WatchSessionDelegateShared()

    private override init() {
        super.init()
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                print("📱 WCSession activation failed: \(error.localizedDescription)")
            } else {
                print("📱 WCSession activated: \(activationState.rawValue)")

                // Notify DeviceManager to detect connected devices
                if activationState == .activated {
                    DeviceManager.shared.onSessionActivated()
                }
            }
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        print("📱 WCSession became inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        print("📱 WCSession deactivated")
        session.activate()
    }

    // Handle requests from Watch
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        if message["request"] as? String == "accounts" {
            var response: [String: Any] = [:]

            // Send OTP accounts
            if let data = UserDefaults.standard.data(forKey: "otp_accounts") {
                response["accounts"] = data
            } else {
                response["accounts"] = Data()
            }

            // Send auth token
            if let authToken = UserDefaults.standard.string(forKey: "auth_token") {
                response["auth_token"] = authToken
            }

            // Send user data
            if let userData = UserDefaults.standard.data(forKey: "current_user") {
                response["user_data"] = userData
            }

            replyHandler(response)
        }
    }
}
#endif

// MARK: - Shared State
class AddAccountWindowState: ObservableObject {
    static let shared = AddAccountWindowState()
    var onAddAccount: ((OTPAccount) -> Void)?
}

// MARK: - macOS Native Window Controller
#if os(macOS)
import AppKit

class AddOTPWindowController: NSObject, NSWindowDelegate {
    static let shared = AddOTPWindowController()
    private var window: NSWindow?
    private var onAddCallback: ((OTPAccount) -> Void)?

    func showWindow(onAdd: @escaping (OTPAccount) -> Void) {
        // Close existing window properly
        if let existingWindow = window {
            existingWindow.delegate = nil
            existingWindow.close()
            window = nil
        }

        onAddCallback = onAdd

        let contentView = AddOTPWindowContentView { [weak self] in
            self?.closeWindow()
        } onAdd: { [weak self] account in
            guard let self = self else { return }
            let callback = self.onAddCallback
            self.closeWindow()
            callback?(account)
        }

        let hostingController = NSHostingController(rootView: contentView)
        let newWindow = NSWindow(contentViewController: hostingController)
        newWindow.title = "Add OTP Account"
        newWindow.styleMask = [.titled, .closable, .resizable]
        newWindow.setContentSize(NSSize(width: 450, height: 550))
        newWindow.center()
        newWindow.delegate = self
        newWindow.makeKeyAndOrderFront(nil)

        self.window = newWindow
    }

    private func closeWindow() {
        onAddCallback = nil
        window?.delegate = nil
        window?.close()
        window = nil
    }

    // MARK: - NSWindowDelegate
    func windowWillClose(_ notification: Notification) {
        if let closingWindow = notification.object as? NSWindow {
            closingWindow.delegate = nil
        }
        onAddCallback = nil
        window = nil
    }
}

struct AddOTPWindowContentView: View {
    var onDismiss: () -> Void
    var onAdd: (OTPAccount) -> Void

    var body: some View {
        AddOTPView(onAdd: { account in
            onAdd(account)
        }, onCancel: {
            onDismiss()
        })
        .frame(minWidth: 400, minHeight: 500)
    }
}
#endif

// MARK: - Mac Catalyst Window Controller
#if targetEnvironment(macCatalyst)
class CatalystWindowController {
    static let shared = CatalystWindowController()
    private var addOTPWindow: UIWindow?

    func showAddOTPWindow(onAdd: @escaping (OTPAccount) -> Void) {
        AddAccountWindowState.shared.onAddAccount = onAdd

        // Request a new window scene
        let activity = NSUserActivity(activityType: "com.quettasoft.app.SecureOTP.addOTP")
        activity.targetContentIdentifier = "addOTP"

        UIApplication.shared.requestSceneSessionActivation(
            nil,
            userActivity: activity,
            options: nil
        ) { error in
            print("Scene activation error: \(error)")
        }
    }
}
#endif

// MARK: - App Entry Point
#if !os(watchOS)
@main
struct SecureOTPApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    #if targetEnvironment(macCatalyst)
    @UIApplicationDelegateAdaptor(CatalystAppDelegate.self) var catalystDelegate
    #endif

    init() {
        // Initialize WatchConnectivity for iOS only
        #if os(iOS) && canImport(WatchConnectivity)
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = WatchSessionDelegateShared.shared
            session.activate()
            print("📱 SecureOTPApp: WCSession initialized and activated")
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            SplashView()
                #if os(macOS)
                .frame(minWidth: 350, minHeight: 500)
                #elseif targetEnvironment(macCatalyst)
                .frame(minWidth: 400, minHeight: 600)
                #endif
        }
        #if os(macOS)
        .windowResizability(.automatic)
        #endif

        #if targetEnvironment(macCatalyst)
        WindowGroup("Add OTP Account", for: String.self) { _ in
            CatalystAddOTPView()
                .frame(minWidth: 450, minHeight: 550)
        }
        .defaultSize(width: 450, height: 550)
        #endif
    }
}
#endif

// MARK: - macOS App Delegate
#if os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate {
    private let windowFrameKey = "MainWindowFrame"

    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.restoreWindowFrame()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        saveWindowFrame()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    private func restoreWindowFrame() {
        guard let window = NSApplication.shared.windows.first else { return }

        if let frameString = UserDefaults.standard.string(forKey: windowFrameKey) {
            window.setFrame(NSRectFromString(frameString), display: true)
        } else {
            if let screen = NSScreen.main {
                let screenHeight = screen.visibleFrame.height
                let height = screenHeight * 0.6
                let width = height * 0.6
                window.setContentSize(NSSize(width: width, height: height))
                window.center()
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResize),
            name: NSWindow.didResizeNotification,
            object: window
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove),
            name: NSWindow.didMoveNotification,
            object: window
        )
    }

    @objc private func windowDidResize(_ notification: Notification) {
        saveWindowFrame()
    }

    @objc private func windowDidMove(_ notification: Notification) {
        saveWindowFrame()
    }

    private func saveWindowFrame() {
        guard let window = NSApplication.shared.windows.first else { return }
        let frameString = NSStringFromRect(window.frame)
        UserDefaults.standard.set(frameString, forKey: windowFrameKey)
    }
}
#endif

// MARK: - Mac Catalyst App Delegate & Views
#if targetEnvironment(macCatalyst)
class CatalystAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if options.userActivities.first?.activityType == "com.quettasoft.app.SecureOTP.addOTP" {
            let config = UISceneConfiguration(name: "Add OTP", sessionRole: connectingSceneSession.role)
            config.delegateClass = AddOTPSceneDelegate.self
            return config
        }
        let config = UISceneConfiguration(name: "Default", sessionRole: connectingSceneSession.role)
        return config
    }
}

class AddOTPSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        // Set window size for Mac Catalyst
        if let titlebar = windowScene.titlebar {
            titlebar.titleVisibility = .visible
        }

        #if targetEnvironment(macCatalyst)
        windowScene.sizeRestrictions?.minimumSize = CGSize(width: 450, height: 550)
        windowScene.sizeRestrictions?.maximumSize = CGSize(width: 600, height: 700)
        #endif
    }
}

struct CatalystAddOTPView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var windowState = AddAccountWindowState.shared

    var body: some View {
        AddOTPView { account in
            windowState.onAddAccount?(account)
            dismiss()
        }
    }
}
#endif
