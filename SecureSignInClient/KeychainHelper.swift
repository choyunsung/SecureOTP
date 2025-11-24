import Foundation
import Security

/// Secure storage helper using iCloud Keychain with end-to-end encryption
/// Supports synchronization across iOS, iPadOS, macOS, and watchOS devices
final class KeychainHelper {
    static let shared = KeychainHelper()

    // Generic service and account names for storing the list of OTP accounts
    private let service = "com.quettasoft.secureotp"
    private let accountsKey = "OTPAccountList"
    private let userAccountKey = "UserAccount"

    // Access group for sharing data between app, watch extension, and widgets
    private let accessGroup = "group.com.quettasoft.secureotp"

    private init() {}

    // MARK: - Account List Specific Methods

    /// Saves OTP accounts to iCloud Keychain with synchronization enabled
    /// - Parameter accounts: Array of OTP accounts to save
    func saveAccounts(_ accounts: [OTPAccount]) {
        do {
            let data = try JSONEncoder().encode(accounts)
            save(data, service: service, account: accountsKey, synchronizable: true)
        } catch {
            print("Failed to encode accounts for keychain: \(error)")
        }
    }

    /// Loads OTP accounts from iCloud Keychain
    /// - Returns: Array of OTP accounts, empty if none found
    func loadAccounts() -> [OTPAccount] {
        guard let data = load(service: service, account: accountsKey, synchronizable: true) else {
            return []
        }

        do {
            let accounts = try JSONDecoder().decode([OTPAccount].self, from: data)
            return accounts
        } catch {
            print("Failed to decode accounts from keychain: \(error)")
            return []
        }
    }

    // MARK: - User Account Methods

    /// Saves user account to iCloud Keychain with synchronization enabled
    /// - Parameter account: User account to save
    func saveUserAccount(_ account: UserAccount) {
        do {
            let data = try JSONEncoder().encode(account)
            save(data, service: service, account: userAccountKey, synchronizable: true)
        } catch {
            print("Failed to encode user account for keychain: \(error)")
        }
    }

    /// Loads user account from iCloud Keychain
    /// - Returns: User account if found, nil otherwise
    func loadUserAccount() -> UserAccount? {
        guard let data = load(service: service, account: userAccountKey, synchronizable: true) else {
            return nil
        }

        do {
            let account = try JSONDecoder().decode(UserAccount.self, from: data)
            return account
        } catch {
            print("Failed to decode user account from keychain: \(error)")
            return nil
        }
    }

    /// Deletes user account from Keychain
    func deleteUserAccount() {
        delete(service: service, account: userAccountKey, synchronizable: true)
    }

    // MARK: - Generic Data Methods with iCloud Sync

    /// Saves data to Keychain with optional iCloud synchronization
    /// - Parameters:
    ///   - data: Data to save
    ///   - service: Service identifier
    ///   - account: Account identifier
    ///   - synchronizable: Enable iCloud Keychain sync (default: false)
    private func save(_ data: Data, service: String, account: String, synchronizable: Bool = false) {
        var query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrAccessGroup: accessGroup
        ] as [CFString: Any]

        if synchronizable {
            query[kSecAttrSynchronizable] = kCFBooleanTrue
        }

        // Delete existing item before adding new one
        SecItemDelete(query as CFDictionary)

        var newQuery = query
        newQuery[kSecValueData] = data

        // Set accessibility to allow access after first unlock
        // This balances security and usability for OTP codes
        newQuery[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(newQuery as CFDictionary, nil)

        if status != errSecSuccess {
            print("Error: \(status) - Failed to save item to Keychain.")
        }
    }

    /// Loads data from Keychain with optional iCloud synchronization
    /// - Parameters:
    ///   - service: Service identifier
    ///   - account: Account identifier
    ///   - synchronizable: Look for iCloud synced items (default: false)
    /// - Returns: Data if found, nil otherwise
    private func load(service: String, account: String, synchronizable: Bool = false) -> Data? {
        var query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrAccessGroup: accessGroup,
            kSecReturnData: kCFBooleanTrue!,
            kSecMatchLimit: kSecMatchLimitOne
        ] as [CFString: Any]

        if synchronizable {
            query[kSecAttrSynchronizable] = kCFBooleanTrue
        }

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        if status == errSecSuccess {
            return dataTypeRef as? Data
        } else {
            if status != errSecItemNotFound {
                print("Error: \(status) - Failed to load item from Keychain.")
            }
            return nil
        }
    }

    /// Deletes an account from Keychain
    /// - Parameters:
    ///   - service: Service identifier
    ///   - account: Account identifier
    ///   - synchronizable: Delete from iCloud Keychain (default: false)
    func delete(service: String, account: String, synchronizable: Bool = false) {
        var query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrAccessGroup: accessGroup
        ] as [CFString: Any]

        if synchronizable {
            query[kSecAttrSynchronizable] = kCFBooleanTrue
        }

        let status = SecItemDelete(query as CFDictionary)

        if status != errSecSuccess && status != errSecItemNotFound {
            print("Error: \(status) - Failed to delete item from Keychain.")
        }
    }
}
