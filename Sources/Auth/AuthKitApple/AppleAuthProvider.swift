//
//  AppleAuthProvider.swift
//  AppFoundation / AuthKitApple
//
//  Sign in with Apple: nonce 생성, ASAuthorizationController 실행, credential 추출.
//  Apple 시트는 이 계층이 직접 present 한다(앱의 로그인 버튼은 트리거일 뿐).
//  `authenticate` 는 `AuthBackend` 가 교환할
//  `.apple(idToken, rawNonce, authorizationCode, fullName, email)` 을 돌려준다.
//
//  외부 SDK 의존은 없지만(AuthenticationServices 만) provider 는 전부
//  `AuthKit{Provider}` product 라는 대칭 규칙으로 분리돼 있다.
//

import AuthenticationServices
import AuthKit
import Foundation
import UIKit
import os

public struct AppleAuthProvider: AuthProvider {

    private let logger = Logger(subsystem: "AppFoundation", category: "AuthKit.Apple")

    public let type: SocialProvider = .apple

    public init() {}

    @MainActor
    public func authenticate(presenter: AuthPresenter?) async throws -> AuthCredential {

        logger.debug("authenticate 시작 — Apple 시트 표시")

        let rawNonce = NonceGenerator.random()

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = NonceGenerator.sha256(rawNonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        let context = AppleAuthorizationContext(anchor: presenter?().view.window)
        controller.delegate = context
        controller.presentationContextProvider = context

        do {
            let appleCredential = try await context.perform(controller)

            guard let tokenData = appleCredential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                logger.error("identityToken 없음 — credential 추출 실패")
                throw AuthKitError.missingCredential
            }

            let authCode = Self.authorizationCode(from: appleCredential)

            logger.debug(
                """
                credential 추출 성공 — idToken \(idToken.count)자, \
                authorizationCode \(authCode == nil ? "없음" : "있음"), \
                fullName \(appleCredential.fullName == nil ? "없음" : "있음")
                """
            )

            return .apple(
                idToken: idToken,
                rawNonce: rawNonce,
                authorizationCode: authCode,
                fullName: appleCredential.fullName,
                email: appleCredential.email
            )

        } catch let error as AuthKitError {
            throw error

        } catch {
            throw mapped(error)
        }
    }

    // Apple 은 클라이언트측 sign-out 이 없다; signOut/handle 은 프로토콜 기본값을 쓴다.

    // MARK: - Credential

    /// 탈퇴 시 토큰 revoke 용 Apple `authorizationCode`(UTF-8). 옵셔널: Apple 이 생략할 수 있다.
    private static func authorizationCode(
        from credential: ASAuthorizationAppleIDCredential
    ) -> String? {
        credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
    }

    // MARK: - Error mapping

    /// 사용자가 시트를 닫으면 `.cancelled`, 그 외는 `.providerFailed`.
    private func mapped(_ error: Error) -> AuthKitError {
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            logger.warning("사용자가 Apple 시트를 취소함")
            return .cancelled
        }
        logger.error("Apple sign-in 실패: \(error.localizedDescription)")
        return .providerFailed(.apple, underlying: error)
    }
}

/// ASAuthorizationController 의 delegate 콜백을 async/await 로 잇고 presentation
/// anchor 를 공급한다. 로그인 시도마다 인스턴스 하나; 컨트롤러가 콜백할 때까지
/// continuation 클로저로 자신을 살려둔다.
@MainActor
private final class AppleAuthorizationContext: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {

    private let anchor: ASPresentationAnchor?
    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?
    // ASAuthorizationController 는 delegate 를 weak 로 잡으므로, 콜백이 정확히 한 번
    // 올 때까지 context 가 자신을 살려둬야 한다. `resume` 이 continuation 과 이
    // self-참조를 함께 비우므로, 콜백은 한 번만 발화하고(이중 resume 크래시 없음)
    // 직후 인스턴스가 해제된다.
    private var selfRef: AppleAuthorizationContext?

    init(anchor: ASPresentationAnchor?) {
        self.anchor = anchor
    }

    func perform(
        _ controller: ASAuthorizationController
    ) async throws -> ASAuthorizationAppleIDCredential {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.selfRef = self
            controller.performRequests()
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        anchor ?? ASPresentationAnchor()
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            resume(with: .failure(AuthKitError.missingCredential))
            return
        }
        resume(with: .success(credential))
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        resume(with: .failure(error))
    }

    /// continuation 을 최대 한 번 resume 하고 self-참조를 놓아 context 를 해제한다.
    /// 이후 콜백(발생하면 안 됨)은 무시한다.
    private func resume(with result: Result<ASAuthorizationAppleIDCredential, Error>) {
        continuation?.resume(with: result)
        continuation = nil
        selfRef = nil
    }
}
