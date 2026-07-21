//
//  DefaultAuthService.swift
//  AppFoundation / AuthKit
//
//  backend + providers 를 조립하는 표준 AuthService. provider 는 SDK 로직을,
//  backend 는 세션 교환/수명주기를, 이 타입은 오케스트레이션만 소유한다 —
//  그래서 SDK 무의존이며 백엔드를 갈아끼워도(Supabase → Firebase) 그대로 쓴다.
//

import Foundation
import os

public final class DefaultAuthService: AuthService, Sendable {

    private let logger = Logger(subsystem: "AppFoundation", category: "AuthKit")

    private let backend: any AuthBackend
    private let providers: [SocialProvider: any AuthProvider]

    public init(backend: any AuthBackend, providers: [any AuthProvider]) {
        self.backend = backend
        self.providers = Dictionary(uniqueKeysWithValues: providers.map { ($0.type, $0) })
    }

    public var currentIdentity: AuthIdentity? {
        get async { await backend.currentIdentity }
    }

    public var authEvents: AsyncStream<(event: AuthEvent, identity: AuthIdentity?)> {
        backend.events
    }

    public func signIn(
        with providerType: SocialProvider,
        presenter: AuthPresenter?
    ) async throws -> SignInResult {

        logger.debug("signIn(\(providerType.rawValue)) 시작")

        let provider = try resolved(providerType)
        let credential = try await provider.authenticate(presenter: presenter)

        logger.debug("provider credential 확보 — backend 교환 중")

        let exchanged = try await backend.exchange(credential)

        // 백엔드 메타데이터보다 방금 로그인한 provider 가 확실하므로 덮어쓴다.
        let identity = AuthIdentity(
            uid: exchanged.uid,
            provider: providerType,
            email: exchanged.email
        )

        logger.info("✅ \(providerType.rawValue) 로그인 성공 — uid=\(identity.uid)")

        return SignInResult(identity: identity, credential: credential)
    }

    public func reauthenticate(
        provider providerType: SocialProvider,
        presenter: AuthPresenter?
    ) async throws -> AuthCredential {
        // 재인증으로 *신선한* credential 을 얻는다(Apple revoke 는 1회성
        // authorizationCode 필요). 서버 탈퇴 EF 가 이 값으로 소셜 토큰 revoke 를
        // 수행하므로, 여기선 값만 확보하고 세션은 건드리지 않는다.
        logger.debug("reauthenticate(\(providerType.rawValue)) 시작")

        let provider = try resolved(providerType)
        let credential = try await provider.authenticate(presenter: presenter)

        logger.info("✅ 재인증 완료 — provider=\(providerType.rawValue)")

        return credential
    }

    public func signOut(scope: SignOutScope) async throws {
        logger.debug("signOut 시작")

        await MainActor.run {
            for provider in providers.values { provider.signOut() }
        }

        try await backend.signOut(scope: scope)

        logger.info("👋 로그아웃 완료")
    }

    public func endSession() async {
        await MainActor.run {
            for provider in providers.values { provider.signOut() }
        }

        // 세션은 이미 서버에서 삭제됐을 수 있으므로 실패는 삼킨다.
        try? await backend.signOut(scope: .local)

        logger.info("👋 세션 정리 완료")
    }

    public var accessToken: String? {
        get async { await backend.accessToken }
    }

    @MainActor
    public func handle(_ url: URL) -> Bool {
        // 먼저 소비하는 provider 가 이긴다 (URL 콜백을 쓰는 SDK 는 소수).
        for provider in providers.values where provider.handle(url) { return true }
        return false
    }

    private func resolved(_ providerType: SocialProvider) throws -> any AuthProvider {
        guard let provider = providers[providerType] else {
            logger.error("등록되지 않은 provider: \(providerType.rawValue)")
            throw AuthKitError.unknownProvider(providerType)
        }
        return provider
    }
}
