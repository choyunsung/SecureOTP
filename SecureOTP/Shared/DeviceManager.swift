import Foundation
#if os(iOS)
import UIKit
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif
#elseif os(macOS)
import AppKit
#endif

struct SyncDevice: Identifiable, Codable {
    let id: String
    let name: String
    let deviceType: DeviceType
    let lastSyncDate: Date
    let isCurrentDevice: Bool

    enum DeviceType: String, Codable {
        case iPhone
        case iPad
        case mac
        case watch

        var iconName: String {
            switch self {
            case .iPhone: return "iphone"
            case .iPad: return "ipad"
            case .mac: return "laptopcomputer"
            case .watch: return "applewatch"
            }
        }

        var displayName: String {
            switch self {
            case .iPhone: return "iPhone"
            case .iPad: return "iPad"
            case .mac: return "Mac"
            case .watch: return "Apple Watch"
            }
        }
    }
}

class DeviceManager: ObservableObject {
    static let shared = DeviceManager()

    @Published var devices: [SyncDevice] = []
    @Published var isLoading = false

    private init() {
        loadDevices()
        #if os(iOS) && canImport(WatchConnectivity)
        setupWatchConnectivity()
        #endif
        // Don't call detectConnectedDevices here - wait for session to activate
    }

    #if os(iOS) && canImport(WatchConnectivity)
    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else { return }

        let session = WCSession.default
        session.delegate = WatchSessionDelegate.shared
        session.activate()
        print("📱 WCSession activation requested in DeviceManager")
    }

    // Called when WCSession is activated
    func onSessionActivated() {
        print("📱 DeviceManager: onSessionActivated callback received")
        detectConnectedDevices()
    }
    #endif

    var currentDevice: SyncDevice {
        let deviceId = getDeviceIdentifier()
        let deviceName = getDeviceName()
        let deviceType = getCurrentDeviceType()

        return SyncDevice(
            id: deviceId,
            name: deviceName,
            deviceType: deviceType,
            lastSyncDate: Date(),
            isCurrentDevice: true
        )
    }

    func loadDevices() {
        isLoading = true

        // Load from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "synced_devices"),
           let decoded = try? JSONDecoder().decode([SyncDevice].self, from: data) {
            devices = decoded
        }

        // Add current device if not in list
        let current = currentDevice
        if !devices.contains(where: { $0.id == current.id }) {
            devices.append(current)
            saveDevices()
        }

        isLoading = false
    }

    func syncDevices() async {
        await MainActor.run { isLoading = true }

        // Detect connected devices
        await MainActor.run {
            detectConnectedDevices()
        }

        // Send OTP data to connected devices
        #if os(iOS) && canImport(WatchConnectivity)
        await syncToWatch()
        #endif

        await MainActor.run { isLoading = false }
    }

    private func detectConnectedDevices() {
        #if os(iOS) && canImport(WatchConnectivity)
        guard WCSession.isSupported() else {
            print("⚠️ WatchConnectivity not supported")
            return
        }

        let session = WCSession.default

        print("📱 DeviceManager - Session state:")
        print("   - Activation state: \(session.activationState.rawValue)")
        print("   - Is paired: \(session.isPaired)")
        print("   - Is watch app installed: \(session.isWatchAppInstalled)")
        print("   - Is reachable: \(session.isReachable)")

        // Check if Apple Watch is paired
        if session.isPaired {
            let watchDevice = SyncDevice(
                id: "apple-watch-paired",
                name: "Apple Watch",
                deviceType: .watch,
                lastSyncDate: Date(),
                isCurrentDevice: false
            )

            // Add or update watch in device list
            if let index = devices.firstIndex(where: { $0.deviceType == .watch }) {
                var updatedDevices = devices
                updatedDevices[index] = watchDevice
                devices = updatedDevices
            } else {
                devices.append(watchDevice)
            }
            saveDevices()

            print("✅ Apple Watch detected and added to device list")
        } else {
            // Remove watch if not paired
            devices.removeAll { $0.deviceType == .watch }
            saveDevices()
            print("ℹ️ No Apple Watch paired")
        }
        #endif
    }

    #if os(iOS) && canImport(WatchConnectivity)
    private func syncToWatch() async {
        guard WCSession.isSupported() else {
            print("⚠️ WatchConnectivity not supported")
            return
        }

        let session = WCSession.default

        print("📱 syncToWatch - Starting sync")
        print("   - Activation state: \(session.activationState.rawValue)")
        print("   - Is paired: \(session.isPaired)")
        print("   - Is watch app installed: \(session.isWatchAppInstalled)")

        guard session.activationState == .activated else {
            print("⚠️ Session not activated (state: \(session.activationState.rawValue))")
            return
        }

        guard session.isPaired else {
            print("⚠️ Watch not paired")
            return
        }

        // Get OTP accounts to sync
        guard let accountsData = UserDefaults.standard.data(forKey: "otp_accounts") else {
            print("ℹ️ No OTP accounts to sync")
            return
        }

        var context: [String: Any] = ["accounts": accountsData]

        // Also send auth data
        if let authToken = UserDefaults.standard.string(forKey: "auth_token") {
            context["auth_token"] = authToken
            print("   - Auth token included")
        }
        if let userData = UserDefaults.standard.data(forKey: "current_user") {
            context["user_data"] = userData
            print("   - User data included")
        }

        print("   - Syncing \((try? JSONDecoder().decode([OTPAccount].self, from: accountsData))?.count ?? 0) OTP accounts")

        do {
            try session.updateApplicationContext(context)
            print("✅ Successfully sent data to Apple Watch via updateApplicationContext")

            // Also try immediate send if reachable
            if session.isReachable {
                session.sendMessage(context, replyHandler: { reply in
                    print("✅ Watch replied: \(reply)")
                }) { error in
                    print("⚠️ sendMessage failed: \(error.localizedDescription)")
                }
            } else {
                print("ℹ️ Watch not reachable for immediate sync")
            }

            // Update last sync time for watch
            if let index = devices.firstIndex(where: { $0.deviceType == .watch }) {
                var updatedDevice = devices[index]
                updatedDevice = SyncDevice(
                    id: updatedDevice.id,
                    name: updatedDevice.name,
                    deviceType: updatedDevice.deviceType,
                    lastSyncDate: Date(),
                    isCurrentDevice: false
                )
                await MainActor.run {
                    devices[index] = updatedDevice
                    saveDevices()
                }
            }
        } catch {
            print("❌ Failed to sync to Watch: \(error.localizedDescription)")
        }
    }
    #endif

    func removeDevice(_ device: SyncDevice) {
        devices.removeAll { $0.id == device.id }
        saveDevices()
    }

    private func saveDevices() {
        if let encoded = try? JSONEncoder().encode(devices) {
            UserDefaults.standard.set(encoded, forKey: "synced_devices")
        }
    }

    private func getDeviceIdentifier() -> String {
        if let identifier = UserDefaults.standard.string(forKey: "device_identifier") {
            return identifier
        }

        let newIdentifier = UUID().uuidString
        UserDefaults.standard.set(newIdentifier, forKey: "device_identifier")
        return newIdentifier
    }

    private func getDeviceName() -> String {
        #if os(iOS)
        return UIDevice.current.name
        #elseif os(macOS)
        return Host.current().localizedName ?? "Mac"
        #elseif os(watchOS)
        return "Apple Watch"
        #else
        return "Unknown Device"
        #endif
    }

    private func getCurrentDeviceType() -> SyncDevice.DeviceType {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .iPad
        } else {
            return .iPhone
        }
        #elseif os(macOS)
        return .mac
        #elseif os(watchOS)
        return .watch
        #else
        return .iPhone
        #endif
    }

}
