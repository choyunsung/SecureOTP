//
//  AuthenticationManager.swift
//  SecureSignInClient
//
//  Apple 로그인 & Google 로그인 통합 관리
//

import Foundation
import Combine
import AuthenticationServices
import SwiftUI

/// 인증 상태
enum AuthState {
    case idle
    case loading
    case authenticated(UserAccount)
    case error(String)
}

/// 인증 관리자
class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()

    @Published var authState: AuthState = .idle
    @Published var currentUser: UserAccount?

    private init() {
        loadCurrentUser()
    }

    // MARK: - Apple Sign In

    /// Apple 로그인 처리
    @MainActor
    func signInWithApple() async {
        authState = .loading

        do {
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]

            // Note: ASAuthorizationController는 iOS/macOS에서 다르게 처리해야 함
            #if os(iOS)
            try await performAppleSignIn(request: request)
            #elseif os(macOS)
            try await performAppleSignInMacOS(request: request)
            #endif
        } catch {
            authState = .error(error.localizedDescription)
        }
    }

    #if os(iOS)
    private func performAppleSignIn(request: ASAuthorizationAppleIDRequest) async throws {
        // iOS에서는 ASAuthorizationController 사용
        // 실제 구현은 Coordinator 패턴 필요
    }
    #endif

    #if os(macOS)
    private func performAppleSignInMacOS(request: ASAuthorizationAppleIDRequest) async throws {
        // macOS에서는 ASAuthorizationController 사용
    }
    #endif

    /// Apple 로그인 결과 처리
    func handleAppleSignInResult(authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            authState = .error("Invalid Apple ID credential")
            return
        }

        let userID = appleIDCredential.user
        let email = appleIDCredential.email ?? "apple.user@privaterelay.appleid.com"
        let fullName = appleIDCredential.fullName

        let username: String
        if let givenName = fullName?.givenName, let familyName = fullName?.familyName {
            username = "\(givenName) \(familyName)"
        } else {
            username = "Apple User"
        }

        let account = UserAccount(
            username: username,
            email: email,
            isVerified: true,
            createdAt: Date(),
            lastVerified: Date(),
            provider: .apple,
            providerUserID: userID
        )

        saveUser(account)
    }

    // MARK: - Google Sign In

    /// Google 로그인 처리
    @MainActor
    func signInWithGoogle() async {
        authState = .loading

        // Google Sign-In SDK 필요
        // 현재는 플레이스홀더

        // 실제 구현 시:
        // 1. GoogleSignIn.GIDSignIn.sharedInstance.signIn()
        // 2. 결과 처리
        // 3. UserAccount 생성

        // 임시 테스트 계정
        let testAccount = UserAccount(
            username: "Google User",
            email: "user@gmail.com",
            isVerified: true,
            createdAt: Date(),
            lastVerified: Date(),
            provider: .google,
            providerUserID: "google_test_id"
        )

        saveUser(testAccount)
    }

    // MARK: - Manual Sign In

    /// 수동 계정 생성
    func createManualAccount(username: String, email: String) {
        let account = UserAccount(
            username: username,
            email: email,
            isVerified: false,
            createdAt: Date(),
            lastVerified: nil,
            provider: .manual,
            providerUserID: nil
        )

        saveUser(account)
    }

    // MARK: - User Management

    /// 사용자 저장
    private func saveUser(_ account: UserAccount) {
        KeychainHelper.shared.saveUserAccount(account)
        currentUser = account
        authState = .authenticated(account)
    }

    /// 현재 사용자 로드
    func loadCurrentUser() {
        if let account = KeychainHelper.shared.loadUserAccount() {
            currentUser = account
            authState = .authenticated(account)
        } else {
            authState = .idle
        }
    }

    /// 로그아웃
    func signOut() {
        KeychainHelper.shared.deleteUserAccount()
        currentUser = nil
        authState = .idle
    }

    /// 사용자 정보 업데이트
    func updateUser(_ account: UserAccount) {
        var updatedAccount = account
        updatedAccount.lastVerified = Date()
        saveUser(updatedAccount)
    }
}
