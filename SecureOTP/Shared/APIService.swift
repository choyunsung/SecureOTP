import Foundation

class APIService {
    static let shared = APIService()

    private let baseURL = "http://51.161.197.177:3100/api"

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
