import Foundation

struct OTPAccount: Identifiable, Codable, Hashable {
    var id = UUID()
    var issuer: String
    var accountName: String
    var secret: String
    
    var displayName: String {
        return issuer.isEmpty ? accountName : "\(issuer) (\(accountName))"
    }
}
