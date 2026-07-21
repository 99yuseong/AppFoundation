//
//  AuthCredential.swift
//  AppFoundation / AuthKit
//

import Foundation

/// provider 의 `authenticate` 결과: SDK 마다 다른 토큰을 담는다.
/// `AuthBackend` 가 이걸 switch 해서 자기 방식(Supabase signInWithIdToken 등)으로
/// 세션과 교환한다.
public enum AuthCredential: Sendable {

    /// Apple: identity token + 검증용 raw nonce, 탈퇴 시 revoke 용 1회성
    /// authorization code, 그리고 Apple 이 최초 인증 때만 주는 이름/이메일.
    case apple(
        idToken: String,
        rawNonce: String,
        authorizationCode: String?,
        fullName: PersonNameComponents?,
        email: String?
    )

    /// Google: identity token(nonce 없음 — 백엔드 콘솔에서 nonce 검사를 건너뜀) +
    /// OAuth access token. access token 은 탈퇴 시 Google revoke 엔드포인트가 받는
    /// 값(idToken 은 revoke 불가).
    case google(idToken: String, accessToken: String)

    /// Kakao: identity token + 검증용 raw nonce. 세션 교환은 `AuthBackend` 책임.
    case kakao(idToken: String, rawNonce: String)

    /// 앱 정의 provider 의 개방 경로. kit 이 모르는 provider(예: naver)의
    /// credential 을 key-value 로 나른다. 백엔드가 이해하는 경우에만 교환된다 —
    /// `RESTAuthBackend` 는 parameters 를 계약 body 에 병합하고,
    /// `SupabaseAuthBackend` 는 `unknownProvider` 를 던진다.
    case custom(provider: SocialProvider, parameters: [String: String])

    public var provider: SocialProvider {
        switch self {
        case .apple: .apple
        case .google: .google
        case .kakao: .kakao
        case let .custom(provider, _): provider
        }
    }
}
