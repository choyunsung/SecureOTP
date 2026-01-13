import Foundation

class APIService {
    static let shared = APIService()

    private let baseURL = "https://secureotp.quetta-soft.com/api"

    private var authToken: String? {
        get { UserDefaults.standard.string(forKey: "auth_token") }
        set { UserDefaults.standard.set(newValue, forKey: "auth_token") }
    }

    private init() {}

    // MARK: - Auth APIs

    func signInWithApple(userId: String, email: String?, name: String?) async throws -> AuthResponse {
        let body: [String: Any] = [
            "userId": userId,
            "email": email ?? "",
            "name": name ?? ""
        ]
        let response: AuthResponse = try await post("/auth/apple", body: body)
        authToken = response.token
        return response
    }

    func signInWithGoogle(userId: String, email: String, name: String?) async throws -> AuthResponse {
        let body: [String: Any] = [
            "userId": userId,
            "email": email,
            "name": name ?? ""
        ]
        let response: AuthResponse = try await post("/auth/google", body: body)
        authToken = response.token
        return response
    }

    func signInWithEmail(email: String, password: String) async throws -> AuthResponse {
        let body: [String: Any] = [
            "email": email,
            "password": password
        ]
        let response: AuthResponse = try await post("/auth/signin", body: body)
        authToken = response.token
        return response
    }

    func signUpWithEmail(name: String, email: String, password: String) async throws -> AuthResponse {
        let body: [String: Any] = [
            "name": name,
            "email": email,
            "password": password
        ]
        let response: AuthResponse = try await post("/auth/signup", body: body)
        authToken = response.token
        return response
    }

    func signOut() {
        authToken = nil
    }

    // MARK: - OTP APIs

    func getOTPAccounts() async throws -> [OTPAccountResponse] {
        let response: OTPListResponse = try await get("/otp")
        return response.accounts
    }

    func addOTPAccount(_ account: OTPAccount) async throws -> OTPAccountResponse {
        let body: [String: Any] = [
            "issuer": account.issuer,
            "accountName": account.accountName,
            "secret": account.secret
        ]
        let response: OTPAccountWrapper = try await post("/otp", body: body)
        return response.account
    }

    func syncOTPAccounts(_ accounts: [OTPAccount]) async throws -> [OTPAccountResponse] {
        let accountsData = accounts.map { account in
            [
                "id": account.id.uuidString,
                "issuer": account.issuer,
                "accountName": account.accountName,
                "secret": account.secret
            ]
        }
        let body: [String: Any] = ["accounts": accountsData]
        let response: OTPListResponse = try await post("/otp/sync", body: body)
        return response.accounts
    }

    func deleteOTPAccount(id: String) async throws {
        try await delete("/otp/\(id)")
    }

    func parseOTPUri(_ uri: String) async throws -> ParsedOTPUri {
        let body: [String: Any] = ["uri": uri]
        return try await post("/otp/parse-uri", body: body)
    }

    // MARK: - Subscription APIs

    func getSubscriptionStatus() async throws -> SubscriptionStatusResponse {
        return try await get("/subscriptions")
    }

    func getSubscriptionHistory() async throws -> SubscriptionHistoryResponse {
        return try await get("/subscriptions/history")
    }

    func verifySubscription(
        productId: String,
        transactionId: String,
        originalTransactionId: String?,
        purchaseDate: Date?,
        expiresDate: Date?,
        receiptData: String?
    ) async throws -> SubscriptionVerifyResponse {
        var body: [String: Any] = [
            "productId": productId,
            "transactionId": transactionId
        ]
        if let originalTransactionId = originalTransactionId {
            body["originalTransactionId"] = originalTransactionId
        }
        if let purchaseDate = purchaseDate {
            body["purchaseDate"] = ISO8601DateFormatter().string(from: purchaseDate)
        }
        if let expiresDate = expiresDate {
            body["expiresDate"] = ISO8601DateFormatter().string(from: expiresDate)
        }
        if let receiptData = receiptData {
            body["receiptData"] = receiptData
        }
        return try await post("/subscriptions/verify", body: body)
    }

    func restoreSubscriptions(transactions: [[String: Any]]) async throws -> SubscriptionRestoreResponse {
        let body: [String: Any] = ["transactions": transactions]
        return try await post("/subscriptions/restore", body: body)
    }

    func cancelSubscription() async throws -> SuccessResponse {
        return try await post("/subscriptions/cancel", body: [:])
    }

    // MARK: - Device APIs

    func getDevices() async throws -> DeviceListResponse {
        return try await get("/devices")
    }

    func registerDevice(
        deviceId: String,
        deviceName: String?,
        deviceModel: String?,
        osVersion: String?,
        appVersion: String?,
        pushToken: String?
    ) async throws -> DeviceRegisterResponse {
        var body: [String: Any] = ["deviceId": deviceId]
        if let deviceName = deviceName { body["deviceName"] = deviceName }
        if let deviceModel = deviceModel { body["deviceModel"] = deviceModel }
        if let osVersion = osVersion { body["osVersion"] = osVersion }
        if let appVersion = appVersion { body["appVersion"] = appVersion }
        if let pushToken = pushToken { body["pushToken"] = pushToken }
        return try await post("/devices/register", body: body)
    }

    func syncDevice(deviceId: String) async throws -> DeviceWrapper {
        return try await post("/devices/\(deviceId)/sync", body: [:])
    }

    func updatePushToken(deviceId: String, pushToken: String?) async throws -> DeviceWrapper {
        let body: [String: Any] = ["pushToken": pushToken ?? NSNull()]
        return try await put("/devices/\(deviceId)/push-token", body: body)
    }

    func removeDevice(deviceId: String) async throws {
        try await delete("/devices/\(deviceId)")
    }

    func logoutAllDevices(exceptDeviceId: String?) async throws -> LogoutAllResponse {
        var body: [String: Any] = [:]
        if let exceptDeviceId = exceptDeviceId {
            body["exceptDeviceId"] = exceptDeviceId
        }
        return try await post("/devices/logout-all", body: body)
    }

    // MARK: - Network Methods

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let url = URL(string: baseURL + path)!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func post<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        let url = URL(string: baseURL + path)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func put<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        let url = URL(string: baseURL + path)!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func delete(_ path: String) async throws {
        let url = URL(string: baseURL + path)!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (_, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        default:
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
}

// MARK: - Response Types

struct AuthResponse: Codable {
    let user: UserResponse
    let token: String
}

struct UserResponse: Codable {
    let id: String
    let email: String
    let name: String
}

struct OTPListResponse: Codable {
    let accounts: [OTPAccountResponse]
}

struct OTPAccountWrapper: Codable {
    let account: OTPAccountResponse
}

struct OTPAccountResponse: Codable {
    let id: String
    let issuer: String
    let accountName: String
    let secret: String
    let algorithm: String
    let digits: Int
    let period: Int

    enum CodingKeys: String, CodingKey {
        case id, issuer, secret, algorithm, digits, period
        case accountName = "account_name"
    }

    func toOTPAccount() -> OTPAccount {
        OTPAccount(
            id: UUID(uuidString: id) ?? UUID(),
            issuer: issuer,
            accountName: accountName,
            secret: secret
        )
    }
}

struct ParsedOTPUri: Codable {
    let type: String
    let issuer: String
    let accountName: String
    let secret: String
    let algorithm: String
    let digits: Int
    let period: Int
}

// MARK: - Subscription Response Types

struct SubscriptionStatusResponse: Codable {
    let subscription: SubscriptionResponse?
    let isSubscribed: Bool
}

struct SubscriptionHistoryResponse: Codable {
    let subscriptions: [SubscriptionResponse]
}

struct SubscriptionVerifyResponse: Codable {
    let subscription: SubscriptionResponse
    let created: Bool?
    let updated: Bool?
}

struct SubscriptionRestoreResponse: Codable {
    let results: [RestoreResult]
    let subscription: SubscriptionResponse?
    let isSubscribed: Bool
}

struct RestoreResult: Codable {
    let transactionId: String
    let action: String
}

struct SubscriptionResponse: Codable {
    let id: String
    let productId: String
    let transactionId: String?
    let originalTransactionId: String?
    let purchaseDate: String?
    let expiresDate: String?
    let isActive: Int

    enum CodingKeys: String, CodingKey {
        case id
        case productId = "product_id"
        case transactionId = "transaction_id"
        case originalTransactionId = "original_transaction_id"
        case purchaseDate = "purchase_date"
        case expiresDate = "expires_date"
        case isActive = "is_active"
    }

    var isCurrentlyActive: Bool {
        guard isActive == 1, let expiresDateStr = expiresDate else { return false }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: expiresDateStr) {
            return date > Date()
        }
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: expiresDateStr) {
            return date > Date()
        }
        return false
    }
}

// MARK: - Device Response Types

struct DeviceListResponse: Codable {
    let devices: [DeviceResponse]
}

struct DeviceRegisterResponse: Codable {
    let device: DeviceResponse
    let created: Bool?
    let updated: Bool?
}

struct DeviceWrapper: Codable {
    let device: DeviceResponse
}

struct LogoutAllResponse: Codable {
    let success: Bool
    let removedCount: Int
}

struct DeviceResponse: Codable {
    let id: String
    let deviceName: String?
    let deviceModel: String?
    let osVersion: String?
    let appVersion: String?
    let pushToken: String?
    let lastSyncAt: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case deviceName = "device_name"
        case deviceModel = "device_model"
        case osVersion = "os_version"
        case appVersion = "app_version"
        case pushToken = "push_token"
        case lastSyncAt = "last_sync_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SuccessResponse: Codable {
    let success: Bool
    let cancelled: Bool?
}

// MARK: - Errors

enum APIError: Error, LocalizedError {
    case invalidResponse
    case unauthorized
    case notFound
    case serverError(Int)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .unauthorized:
            return "Please sign in again"
        case .notFound:
            return "Resource not found"
        case .serverError(let code):
            return "Server error: \(code)"
        case .networkError(let error):
            return error.localizedDescription
        }
    }
}
