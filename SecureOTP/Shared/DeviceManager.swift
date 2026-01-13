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
    @Published var serverDevices: [DeviceResponse] = []
    @Published var isLoading = false

    private init() {
        loadDevices()
        #if os(iOS) && canImport(WatchConnectivity)
        setupWatchConnectivity()
        #endif
        // Don't call detectConnectedDevices here - wait for session to activate

        // Sync with server if logged in
        Task {
            await registerCurrentDeviceToServer()
            await loadDevicesFromServer()
        }
    }

    #if os(iOS) && canImport(WatchConnectivity)
    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else { return }

        // Don't set delegate here - let WatchConnectivityManager handle it
        print("📱 DeviceManager waiting for WCSession activation")

        // Wait for session to activate (managed by WatchConnectivityManager)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.onSessionActivated()
        }
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
        } catch {
            print("⚠️ updateApplicationContext failed: \(error.localizedDescription)")
            // Fallback: use transferUserInfo which doesn't check isWatchAppInstalled
            session.transferUserInfo(context)
            print("📤 Sent data via transferUserInfo (fallback)")
        }

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
    }
    #endif

    func removeDevice(_ device: SyncDevice) {
        devices.removeAll { $0.id == device.id }
        saveDevices()

        // Also remove from server
        Task {
            await removeDeviceFromServer(deviceId: device.id)
        }
    }

    // MARK: - Server API Integration

    func loadDevicesFromServer() async {
        guard UserDefaults.standard.string(forKey: "auth_token") != nil else { return }

        do {
            let response = try await APIService.shared.getDevices()
            await MainActor.run {
                self.serverDevices = response.devices
            }
        } catch {
            print("Failed to load devices from server: \(error.localizedDescription)")
        }
    }

    func registerCurrentDeviceToServer() async {
        guard UserDefaults.standard.string(forKey: "auth_token") != nil else { return }

        let device = currentDevice
        let osVersion = getOSVersion()
        let appVersion = getAppVersion()

        do {
            let response = try await APIService.shared.registerDevice(
                deviceId: device.id,
                deviceName: device.name,
                deviceModel: getDeviceModel(),
                osVersion: osVersion,
                appVersion: appVersion,
                pushToken: nil
            )

            await MainActor.run {
                // Update serverDevices if device was created/updated
                if let index = self.serverDevices.firstIndex(where: { $0.id == response.device.id }) {
                    self.serverDevices[index] = response.device
                } else {
                    self.serverDevices.append(response.device)
                }
            }

            print("✅ Device registered to server: \(response.device.id)")
        } catch {
            print("Failed to register device to server: \(error.localizedDescription)")
        }
    }

    func syncDeviceToServer() async {
        guard UserDefaults.standard.string(forKey: "auth_token") != nil else { return }

        let deviceId = getDeviceIdentifier()

        do {
            let response = try await APIService.shared.syncDevice(deviceId: deviceId)
            await MainActor.run {
                if let index = self.serverDevices.firstIndex(where: { $0.id == response.device.id }) {
                    self.serverDevices[index] = response.device
                }
            }
        } catch {
            print("Failed to sync device to server: \(error.localizedDescription)")
        }
    }

    func updatePushToken(_ token: String) async {
        guard UserDefaults.standard.string(forKey: "auth_token") != nil else { return }

        let deviceId = getDeviceIdentifier()

        do {
            let response = try await APIService.shared.updatePushToken(deviceId: deviceId, pushToken: token)
            await MainActor.run {
                if let index = self.serverDevices.firstIndex(where: { $0.id == response.device.id }) {
                    self.serverDevices[index] = response.device
                }
            }
        } catch {
            print("Failed to update push token: \(error.localizedDescription)")
        }
    }

    func removeDeviceFromServer(deviceId: String) async {
        guard UserDefaults.standard.string(forKey: "auth_token") != nil else { return }

        do {
            try await APIService.shared.removeDevice(deviceId: deviceId)
            await MainActor.run {
                self.serverDevices.removeAll { $0.id == deviceId }
            }
        } catch {
            print("Failed to remove device from server: \(error.localizedDescription)")
        }
    }

    func logoutFromAllDevices(keepCurrent: Bool = true) async {
        guard UserDefaults.standard.string(forKey: "auth_token") != nil else { return }

        let exceptId = keepCurrent ? getDeviceIdentifier() : nil

        do {
            let response = try await APIService.shared.logoutAllDevices(exceptDeviceId: exceptId)
            print("Logged out from \(response.removedCount) devices")
            await loadDevicesFromServer()
        } catch {
            print("Failed to logout from all devices: \(error.localizedDescription)")
        }
    }

    private func getOSVersion() -> String {
        #if os(iOS)
        return UIDevice.current.systemVersion
        #elseif os(macOS)
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        #elseif os(watchOS)
        return "watchOS"
        #else
        return "Unknown"
        #endif
    }

    private func getAppVersion() -> String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private func getDeviceModel() -> String {
        #if os(iOS)
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
        return modelCode
        #elseif os(macOS)
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
        #else
        return "Unknown"
        #endif
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
