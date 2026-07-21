//
//  DefaultAuthServiceTests.swift
//  AppFoundation / AuthKitTests
//
//  Stub provider + stub backend 로 오케스트레이션 로직만 검증한다.
//

import Foundation
import Testing
@testable import AuthKit

@Suite("DefaultAuthService")
struct DefaultAuthServiceTests {

    // MARK: - Stubs

    private final class StubProvider: AuthProvider, @unchecked Sendable {
        let type: SocialProvider
        let branding: SocialLoginBranding
        let result: Result<AuthCredential, AuthKitError>
        private(set) var signOutCallCount = 0

        init(
            type: SocialProvider,
            branding: SocialLoginBranding = .apple(),
            result: Result<AuthCredential, AuthKitError>
        ) {
            self.type = type
            self.branding = branding
            self.result = result
        }

        func authenticate(presenter: AuthPresenter?) async throws -> AuthCredential {
            try result.get()
        }

        func signOut() { signOutCallCount += 1 }
    }

    private final class StubBackend: AuthBackend, @unchecked Sendable {
        private(set) var exchangedCredentials: [AuthCredential] = []
        private(set) var signOutScopes: [SignOutScope] = []
        var signOutError: AuthKitError?

        var currentIdentity: AuthIdentity? { get async { nil } }
        var events: AsyncStream<(event: AuthEvent, identity: AuthIdentity?)> {
            AsyncStream { $0.finish() }
        }

        func exchange(_ credential: AuthCredential) async throws -> AuthIdentity {
            exchangedCredentials.append(credential)
            return AuthIdentity(uid: "backend-uid", provider: nil, email: "user@example.com")
        }

        func signOut(scope: SignOutScope) async throws {
            signOutScopes.append(scope)
            if let signOutError { throw signOutError }
        }

        var accessToken: String? { get async { "stub-token" } }
    }

    private static func appleCredential(code: String? = "code") -> AuthCredential {
        .apple(idToken: "id-token", rawNonce: "nonce", authorizationCode: code, fullName: nil, email: nil)
    }

    // MARK: - loginOptions

    @Test("loginOptions — 주입 순서가 보존되고 provider 의 branding 이 전달된다")
    func loginOptionsOrderAndBranding() {
        let naver = SocialProvider(rawValue: "naver")
        let naverBranding = SocialLoginBranding(
            title: "네이버로 로그인",
            foreground: .white,
            background: .green,
            logo: .sfSymbol("n.square.fill")
        )
        let service = DefaultAuthService(
            backend: StubBackend(),
            providers: [
                StubProvider(type: .kakao, branding: .kakao, result: .success(.kakao(idToken: "t", rawNonce: "n"))),
                StubProvider(type: .apple, branding: .apple(.whiteOutline), result: .success(Self.appleCredential())),
                StubProvider(type: naver, branding: naverBranding,
                             result: .success(.custom(provider: naver, parameters: [:]))),
            ]
        )

        let options = service.loginOptions

        // 주입 순서 = 노출 순서 (kakao → apple → naver)
        #expect(options.map(\.provider) == [.kakao, .apple, naver])
        // provider 가 소유한 branding 이 그대로 흐른다
        #expect(options[1].branding.border != nil)   // whiteOutline 은 테두리 있음
        #expect(options[2].branding.title == "네이버로 로그인")
    }

    @Test("커스텀 provider — 등록만 하면 signIn 이 동일하게 동작한다")
    func signInCustomProvider() async throws {
        let naver = SocialProvider(rawValue: "naver")
        let backend = StubBackend()
        let provider = StubProvider(
            type: naver,
            result: .success(.custom(provider: naver, parameters: ["id_token": "t"]))
        )
        let service = DefaultAuthService(backend: backend, providers: [provider])

        let result = try await service.signIn(with: naver)

        #expect(backend.exchangedCredentials.count == 1)
        #expect(result.identity.provider == naver)
    }

    // MARK: - signIn

    @Test("signIn 성공 — credential 이 backend 로 전달되고 SignInResult 에 실려 돌아온다")
    func signInSuccess() async throws {
        let backend = StubBackend()
        let provider = StubProvider(type: .apple, result: .success(Self.appleCredential()))
        let service = DefaultAuthService(backend: backend, providers: [provider])

        let result = try await service.signIn(with: .apple)

        #expect(backend.exchangedCredentials.count == 1)
        #expect(result.identity.uid == "backend-uid")
        #expect(result.identity.email == "user@example.com")
        // 백엔드 메타데이터(nil)보다 방금 로그인한 provider 가 우선
        #expect(result.identity.provider == .apple)

        guard case .apple = result.credential else {
            Issue.record("credential 이 SignInResult 에 실려 오지 않음")
            return
        }
    }

    @Test("미등록 provider — unknownProvider throw, backend 미호출")
    func signInUnknownProvider() async {
        let backend = StubBackend()
        let provider = StubProvider(type: .apple, result: .success(Self.appleCredential()))
        let service = DefaultAuthService(backend: backend, providers: [provider])

        await #expect(throws: AuthKitError.self) {
            try await service.signIn(with: .kakao)
        }
        #expect(backend.exchangedCredentials.isEmpty)
    }

    @Test("취소 전파 — provider 취소가 isCancelled 로 드러나고 backend 미호출")
    func signInCancelled() async {
        let backend = StubBackend()
        let provider = StubProvider(type: .apple, result: .failure(.cancelled))
        let service = DefaultAuthService(backend: backend, providers: [provider])

        do {
            _ = try await service.signIn(with: .apple)
            Issue.record("취소가 throw 되지 않음")
        } catch let error as AuthKitError {
            #expect(error.isCancelled)
        } catch {
            Issue.record("AuthKitError 가 아닌 에러: \(error)")
        }
        #expect(backend.exchangedCredentials.isEmpty)
    }

    // MARK: - reauthenticate

    @Test("reauthenticate — credential 만 확보하고 세션 교환은 하지 않는다")
    func reauthenticateDoesNotExchange() async throws {
        let backend = StubBackend()
        let provider = StubProvider(type: .apple, result: .success(Self.appleCredential(code: "fresh")))
        let service = DefaultAuthService(backend: backend, providers: [provider])

        let credential = try await service.reauthenticate(provider: .apple)

        #expect(backend.exchangedCredentials.isEmpty)
        let withdrawal = try WithdrawalCredential(folding: credential)
        #expect(withdrawal == .apple(authorizationCode: "fresh"))
    }

    // MARK: - signOut / endSession

    @Test("signOut — 전 provider 정리 후 backend 에 scope 전달")
    func signOutOrder() async throws {
        let backend = StubBackend()
        let apple = StubProvider(type: .apple, result: .success(Self.appleCredential()))
        let kakao = StubProvider(type: .kakao, result: .success(.kakao(idToken: "t", rawNonce: "n")))
        let service = DefaultAuthService(backend: backend, providers: [apple, kakao])

        try await service.signOut(scope: .global)

        #expect(apple.signOutCallCount == 1)
        #expect(kakao.signOutCallCount == 1)
        #expect(backend.signOutScopes == [.global])
    }

    @Test("endSession — backend 실패를 삼키고 provider 는 정리된다")
    func endSessionSwallowsBackendError() async {
        let backend = StubBackend()
        backend.signOutError = .sessionNotFound
        let provider = StubProvider(type: .apple, result: .success(Self.appleCredential()))
        let service = DefaultAuthService(backend: backend, providers: [provider])

        await service.endSession()

        #expect(provider.signOutCallCount == 1)
        #expect(backend.signOutScopes == [.local])
    }
}
