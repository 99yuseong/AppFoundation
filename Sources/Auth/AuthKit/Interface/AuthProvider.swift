//
//  AuthProvider.swift
//  AppFoundation / AuthKit
//

import Foundation

/// 소셜 provider 하나당 하나. 자신의 SDK 와 provider 고유 UI 를 소유하고,
/// 인증 왕복을 실행해 `AuthBackend` 가 세션과 교환할 provider별 `AuthCredential`
/// 을 돌려준다. 로그인·회원탈퇴 재인증 모두 이 `authenticate` 를 쓴다 — 탈퇴 시
/// 소셜 토큰 revoke(App Store 5.1.1(v))는 서버(Edge Function)가 처리하므로
/// provider 는 revoke 를 직접 호출하지 않는다.
public protocol AuthProvider: Sendable {

    var type: SocialProvider { get }

    /// provider 의 로그인 UI 를 present 하고 credential 을 돌려준다.
    @MainActor
    func authenticate(presenter: AuthPresenter?) async throws -> AuthCredential

    /// provider 로컬 세션을 정리한다(로그아웃 시).
    @MainActor
    func signOut()

    /// OAuth 콜백 URL 을 provider SDK 로 전달한다(SDK 가 사용하는 경우).
    @MainActor
    func handle(_ url: URL) -> Bool
}

extension AuthProvider {

    @MainActor public func signOut() {}

    @MainActor public func handle(_ url: URL) -> Bool { false }
}
