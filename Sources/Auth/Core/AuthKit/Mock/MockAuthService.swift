//
//  MockAuthService.swift
//  AppFoundation / AuthKit
//
//  실제 소셜 로그인이 연결되기 전에 쓰는 인메모리 auth. SDK 왕복 없이
//  앱이 로그인된 상태로 빌드/실행되게 한다 (프리뷰/테스트용).
//

import Foundation

public actor MockAuthService: AuthService {

    private var identity: AuthIdentity?
    private let fixedUID: String
    private let options: [SocialLoginOption]

    public init(
        uid: String = "mock-user",
        options: [SocialLoginOption] = [
            SocialLoginOption(provider: .apple, branding: .apple()),
            SocialLoginOption(provider: .google, branding: .google),
            SocialLoginOption(provider: .kakao, branding: .kakao),
        ]
    ) {
        self.fixedUID = uid
        self.options = options
    }

    public var currentIdentity: AuthIdentity? { identity }

    /// 백엔드가 없으니 이벤트도 없다 — 즉시 끝나는 빈 스트림.
    public nonisolated var authEvents: AsyncStream<(event: AuthEvent, identity: AuthIdentity?)> {
        AsyncStream { $0.finish() }
    }

    public nonisolated var loginOptions: [SocialLoginOption] { options }

    public func signIn(
        with provider: SocialProvider,
        presenter: AuthPresenter?
    ) async throws -> SignInResult {
        let signedIn = AuthIdentity(uid: fixedUID, provider: provider)
        identity = signedIn
        return SignInResult(identity: signedIn, credential: Self.cannedCredential(for: provider))
    }

    public func reauthenticate(
        provider: SocialProvider,
        presenter: AuthPresenter?
    ) async throws -> AuthCredential {
        // 재인증은 세션을 건드리지 않는다 — provider별 canned credential 만 돌려준다.
        Self.cannedCredential(for: provider)
    }

    public func signOut(scope: SignOutScope) async throws {
        identity = nil
    }

    public func endSession() async {
        identity = nil
    }

    public var accessToken: String? {
        identity == nil ? nil : "mock-access-token"
    }

    public nonisolated func handle(_ url: URL) -> Bool { false }

    private static func cannedCredential(for provider: SocialProvider) -> AuthCredential {
        switch provider {
        case .apple:
            .apple(
                idToken: "mock-apple-id-token",
                rawNonce: "mock-nonce",
                authorizationCode: "mock-apple-code",
                fullName: nil,
                email: nil
            )
        case .google:
            .google(idToken: "mock-google-id-token", accessToken: "mock-google-token")
        case .kakao:
            .kakao(idToken: "mock-kakao-id-token", rawNonce: "mock-nonce")
        default:
            .custom(provider: provider, parameters: ["id_token": "mock-custom-id-token"])
        }
    }
}
