//
//  UserAccount.swift
//  SecureSignInClient
//
//  사용자 계정 인증 모델
//

import Foundation

/// 인증 제공자 타입
enum AuthProvider: String, Codable {
    case apple = "Apple"
    case google = "Google"
    case manual = "Manual"
}

/// 사용자 본인의 계정 정보
struct UserAccount: Identifiable, Codable, Hashable {
    var id = UUID()
    var username: String              // 사용자 이름
    var email: String                 // 이메일
    var isVerified: Bool = false      // 인증 여부
    var createdAt: Date = Date()      // 생성일
    var lastVerified: Date?           // 마지막 인증 시간
    var provider: AuthProvider = .manual  // 인증 제공자
    var providerUserID: String?       // 제공자의 사용자 ID

    var displayName: String {
        return username
    }

    var providerIcon: String {
        switch provider {
        case .apple:
            return "applelogo"
        case .google:
            return "g.circle.fill"
        case .manual:
            return "person.circle.fill"
        }
    }
}

/// 사용자 인증 상태
enum AuthenticationStatus {
    case notAuthenticated
    case authenticated(UserAccount)
    case pending
}
