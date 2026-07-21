//
//  GoogleAuthProvider.swift
//  AppFoundation / AuthKitGoogle
//
//  Google 로그인: GIDSignIn 구성, 계정 피커 present, SDK 에러 매핑.
//  `authenticate` 는 `.google(idToken, accessToken)` 을 돌려준다 — idToken 은
//  `AuthBackend` 가 세션과 교환하고, access token 은 탈퇴 시 서버가 Google 토큰
//  revoke 에 쓴다. client ID 는 앱 config 에서 주입받는다.
//

import AuthKit
import Foundation
import GoogleSignIn
import os

public struct GoogleAuthProvider: AuthProvider {

    private let logger = Logger(subsystem: "AppFoundation", category: "AuthKit.Google")

    public let type: SocialProvider = .google

    /// 로그인 버튼 브랜드 디자인 — 기본은 공식 스펙(.google). 생성자로 오버라이드한다.
    public let branding: SocialLoginBranding

    private let clientID: String

    public init(clientID: String, branding: SocialLoginBranding = .google) {
        self.clientID = clientID
        self.branding = branding
    }

    @MainActor
    public func authenticate(presenter: AuthPresenter?) async throws -> AuthCredential {

        logger.debug("authenticate 시작 — Google 피커 표시")

        guard let presenter else {
            logger.error("presenter 없음 — Google 피커를 띄울 수 없음")
            throw AuthKitError.missingPresenter(.google)
        }

        configureIfNeeded()

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter())

            guard let idToken = result.user.idToken?.tokenString else {
                logger.error("idToken 없음 — credential 추출 실패")
                throw AuthKitError.missingCredential
            }

            // accessToken 은 GIDGoogleUser 에서 non-optional; 탈퇴 시 서버가
            // Google revoke 에 쓰는 값이다(idToken 은 revoke 불가).
            let accessToken = result.user.accessToken.tokenString

            logger.debug("credential 추출 성공 — idToken \(idToken.count)자, accessToken \(accessToken.count)자")

            return .google(idToken: idToken, accessToken: accessToken)

        } catch let error as AuthKitError {
            throw error

        } catch {
            throw mapped(error)
        }
    }

    @MainActor
    public func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }

    @MainActor
    public func handle(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    // MARK: - Error mapping

    /// 사용자가 피커를 닫으면 `.cancelled`, 그 외는 `.providerFailed`.
    private func mapped(_ error: Error) -> AuthKitError {
        let nsError = error as NSError
        if nsError.domain == kGIDSignInErrorDomain,
           nsError.code == GIDSignInError.canceled.rawValue {
            logger.warning("사용자가 Google 피커를 취소함")
            return .cancelled
        }
        logger.error("Google sign-in 실패: \(error.localizedDescription)")
        return .providerFailed(.google, underlying: error)
    }

    // MARK: - Configuration

    /// 앱 config 로 GIDSignIn 을 구성한다. 이미 구성됐으면 no-op.
    @MainActor
    private func configureIfNeeded() {

        guard GIDSignIn.sharedInstance.configuration == nil else { return }

        guard !clientID.isEmpty else {
            logger.warning("clientID 비어있음 — Google 로그인 실패 예정 (GOOGLE_CLIENT_ID 미설정?)")
            return
        }

        logger.debug("GIDSignIn 구성 — clientID …\(clientID.suffix(20))")
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
    }
}
