import Foundation

struct OTPAccount: Identifiable, Codable, Equatable {
    let id: UUID
    let issuer: String
    let accountName: String
    let secret: String

    init(id: UUID = UUID(), issuer: String, accountName: String, secret: String) {
        self.id = id
        self.issuer = issuer
        self.accountName = accountName
        self.secret = secret
    }

    // Parse otpauth:// URI
    static func parse(uri: String) -> OTPAccount? {
        guard uri.hasPrefix("otpauth://"),
              let url = URL(string: uri) else {
            return nil
        }

        let path = url.path.hasPrefix("/") ? String(url.path.dropFirst()) : url.path
        guard let secret = url.queryValue(for: "secret") else {
            return nil
        }

        var issuer = url.queryValue(for: "issuer") ?? ""
        var accountName = path

        // Parse "Issuer:account" format
        if path.contains(":") {
            let parts = path.components(separatedBy: ":")
            if issuer.isEmpty { issuer = parts[0] }
            accountName = parts.dropFirst().joined(separator: ":")
        }

        return OTPAccount(
            issuer: issuer,
            accountName: accountName,
            secret: secret.uppercased().replacingOccurrences(of: " ", with: "")
        )
    }
}

extension URL {
    func queryValue(for key: String) -> String? {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }
        return queryItems.first { $0.name == key }?.value
    }
}
