import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    @Published var isReachable = false

    private override init() {
        super.init()

        #if !os(watchOS)
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
        #endif

        #if os(watchOS)
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
        #endif
    }

    // Send OTP accounts to Watch
    func syncAccountsToWatch(_ accounts: [OTPAccount]) {
        #if !os(watchOS)
        guard WCSession.default.activationState == .activated else {
            print("WCSession not activated")
            return
        }

        if let encoded = try? JSONEncoder().encode(accounts) {
            let message = ["accounts": encoded]

            // Try to send immediately if Watch is reachable
            if WCSession.default.isReachable {
                WCSession.default.sendMessage(message, replyHandler: nil) { error in
                    print("Failed to send message: \(error.localizedDescription)")
                }
            }

            // Also update application context for background sync
            do {
                try WCSession.default.updateApplicationContext(message)
                print("✅ Synced \(accounts.count) accounts to Watch")
            } catch {
                print("Failed to update context: \(error.localizedDescription)")
            }
        }
        #endif
    }

    // Request accounts from iPhone (Watch only)
    func requestAccountsFromiPhone() {
        #if os(watchOS)
        guard WCSession.default.activationState == .activated,
              WCSession.default.isReachable else {
            print("iPhone not reachable")
            return
        }

        WCSession.default.sendMessage(["request": "accounts"], replyHandler: { reply in
            if let accountsData = reply["accounts"] as? Data,
               let accounts = try? JSONDecoder().decode([OTPAccount].self, from: accountsData) {

                // Save to local storage
                UserDefaults.standard.set(accountsData, forKey: "otp_accounts")

                // Notify observers
                NotificationCenter.default.post(
                    name: NSNotification.Name("WatchAccountsUpdated"),
                    object: accounts
                )

                print("✅ Received \(accounts.count) accounts from iPhone")
            }
        }) { error in
            print("Failed to request accounts: \(error.localizedDescription)")
        }
        #endif
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable

            if let error = error {
                print("📱 WCSession activation failed: \(error.localizedDescription)")
            } else {
                print("📱 WCSession activated: \(activationState.rawValue)")

                // Notify DeviceManager to detect connected devices now that session is active
                #if !os(watchOS)
                if activationState == .activated {
                    DeviceManager.shared.onSessionActivated()
                }
                #endif
            }
        }
    }

    #if !os(watchOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("WCSession became inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        print("WCSession deactivated")
        session.activate()
    }

    // Handle requests from Watch
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        if message["request"] as? String == "accounts" {
            // Load accounts from local storage
            if let data = UserDefaults.standard.data(forKey: "otp_accounts") {
                replyHandler(["accounts": data])
            } else {
                replyHandler(["accounts": Data()])
            }
        }
    }
    #endif

    #if os(watchOS)
    // Receive accounts from iPhone
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let accountsData = message["accounts"] as? Data {
            // Save to local storage
            UserDefaults.standard.set(accountsData, forKey: "otp_accounts")

            if let accounts = try? JSONDecoder().decode([OTPAccount].self, from: accountsData) {
                // Notify observers
                NotificationCenter.default.post(
                    name: NSNotification.Name("WatchAccountsUpdated"),
                    object: accounts
                )

                print("✅ Received \(accounts.count) accounts from iPhone via message")
            }
        }
    }

    // Receive application context updates
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        if let accountsData = applicationContext["accounts"] as? Data {
            // Save to local storage
            UserDefaults.standard.set(accountsData, forKey: "otp_accounts")

            if let accounts = try? JSONDecoder().decode([OTPAccount].self, from: accountsData) {
                // Notify observers
                NotificationCenter.default.post(
                    name: NSNotification.Name("WatchAccountsUpdated"),
                    object: accounts
                )

                print("✅ Received \(accounts.count) accounts from iPhone via context")
            }
        }
    }
    #endif

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            print("Watch reachability changed: \(session.isReachable)")
        }
    }
}
#endif
