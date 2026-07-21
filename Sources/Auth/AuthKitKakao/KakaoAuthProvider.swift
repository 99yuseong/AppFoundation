//
//  KakaoAuthProvider.swift
//  AppFoundation / AuthKitKakao
//
//  Kakao 네이티브 로그인: KakaoSDK(OIDC)로 id_token 을 받는다. 세션 교환은
//  `AuthBackend` 책임 — Supabase 라면 GoTrue id_token grant (AuthKitSupabase 의
//  KakaoIdTokenGrant 참조).
//
//  nonce 구도: 백엔드(GoTrue)는 SHA256(요청 nonce) == id_token nonce claim 으로
//  검증한다. Kakao 는 전달한 nonce 를 원문 그대로 claim 에 넣으므로, SDK 에는
//  해시를 주고 credential 에는 raw 를 담아 백엔드에 준다. (Apple 과 동일 구도)
//

import AuthKit
import Foundation
import KakaoSDKAuth
import KakaoSDKCommon
import KakaoSDKUser
import os

public struct KakaoAuthProvider: AuthProvider {

    private static let logger = Logger(subsystem: "AppFoundation", category: "AuthKit.Kakao")

    public let type: SocialProvider = .kakao

    public init() {}

    /// 앱 launch 시 1회 호출 — KakaoSDK 초기화.
    /// (Info.plist 의 KAKAO_APP_KEY 를 `ConfigValues.require` 로 읽어 넘기면 된다)
    @MainActor
    public static func initialize(appKey: String) {
        KakaoSDK.initSDK(appKey: appKey)
    }

    @MainActor
    public func authenticate(presenter: AuthPresenter?) async throws -> AuthCredential {

        Self.logger.debug("authenticate 시작 — Kakao 로그인")

        let rawNonce = NonceGenerator.random()
        let oauthToken = try await Self.kakaoToken(nonce: NonceGenerator.sha256(rawNonce))

        // OIDC 미활성(콘솔 설정 누락) 시 idToken 이 nil 로 온다
        guard let idToken = oauthToken.idToken else {
            Self.logger.error("idToken 없음 — Kakao 콘솔 OpenID Connect 활성화 확인 필요")
            throw AuthKitError.missingCredential
        }

        Self.logger.debug("credential 추출 성공 — idToken \(idToken.count)자")

        return .kakao(idToken: idToken, rawNonce: rawNonce)
    }

    /// Kakao SDK 가 로컬에 보관한 토큰 정리 (best-effort, 실패 무시).
    @MainActor
    public func signOut() {
        UserApi.shared.logout { _ in }
    }

    @MainActor
    public func handle(_ url: URL) -> Bool {
        guard AuthApi.isKakaoTalkLoginUrl(url) else { return false }
        return AuthController.handleOpenUrl(url: url)
    }

    // MARK: - Kakao SDK

    @MainActor
    private static func kakaoToken(nonce: String) async throws -> OAuthToken {
        try await withCheckedThrowingContinuation { continuation in

            let completion: (OAuthToken?, Error?) -> Void = { token, error in
                if let error {
                    continuation.resume(throwing: mapKakaoError(error))
                } else if let token {
                    continuation.resume(returning: token)
                } else {
                    continuation.resume(throwing: AuthKitError.missingCredential)
                }
            }

            if UserApi.isKakaoTalkLoginAvailable() {
                // 카카오톡 앱 스위치 로그인
                UserApi.shared.loginWithKakaoTalk(nonce: nonce, completion: completion)
            } else {
                // 카카오톡 미설치 → SDK 가 관리하는 계정 로그인 (동일하게 id_token 반환)
                UserApi.shared.loginWithKakaoAccount(nonce: nonce, completion: completion)
            }
        }
    }

    // MARK: - Error mapping

    /// 취소 판정 2종을 `.cancelled` 로, 나머지는 `.providerFailed` 로 매핑한다.
    /// internal: 단위 테스트 대상.
    static func mapKakaoError(_ error: Error) -> AuthKitError {
        guard let sdkError = error as? SdkError else {
            return .providerFailed(.kakao, underlying: error)
        }

        // 카카오톡 앱 스위치 중 취소
        if sdkError.isClientFailed,
           case .Cancelled = sdkError.getClientError().reason {
            logger.warning("사용자가 카카오톡 로그인을 취소함")
            return .cancelled
        }

        // 계정 웹 로그인에서 취소(동의 화면 닫기 등)는 access_denied 로 온다
        if sdkError.isAuthFailed,
           case .AccessDenied = sdkError.getAuthError().reason {
            logger.warning("사용자가 카카오 계정 로그인을 취소함")
            return .cancelled
        }

        logger.error("Kakao sign-in 실패: \(error.localizedDescription)")
        return .providerFailed(.kakao, underlying: error)
    }
}
