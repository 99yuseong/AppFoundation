//
//  SupabaseAuthBackend.swift
//  AppFoundation / AuthKitSupabase
//
//  Supabase 기반 AuthBackend. provider 가 돌려준 AuthCredential 을
//  signInWithIdToken(OpenIDConnectCredentials)으로 교환한다. Kakao 는 supabase-swift
//  가 아직 지원하지 않아 GoTrue REST 를 직접 호출한다(KakaoIdTokenGrant 참조).
//
//  ⚠️ SupabaseClient 는 앱이 주입한다 — 앱 전역에 클라이언트는 하나여야 로그인
//  세션이 REST 요청 Bearer 에 실린다. 패키지가 자체 클라이언트를 만들면 안 된다.
//

import AuthKit
import Foundation
import Supabase
import os

public final class SupabaseAuthBackend: AuthBackend, @unchecked Sendable {

    public struct Configuration: Sendable {
        /// Kakao GoTrue REST grant 전용 — SupabaseClient 가 URL/key 를 공개하지
        /// 않으므로 명시 주입받는다.
        public let supabaseURL: URL
        public let apiKey: String
        /// Kakao REST grant 요청에 실을 추가 헤더(x-device-id 등 앱 커스텀 헤더).
        public var additionalHeaders: [String: String]

        public init(
            supabaseURL: URL,
            apiKey: String,
            additionalHeaders: [String: String] = [:]
        ) {
            self.supabaseURL = supabaseURL
            self.apiKey = apiKey
            self.additionalHeaders = additionalHeaders
        }
    }

    private let logger = Logger(subsystem: "AppFoundation", category: "AuthKit.Supabase")

    // SupabaseClient 는 내부적으로 스레드 세이프하며, 저장 프로퍼티는 전부 불변 —
    // @unchecked 는 SupabaseClient 의 Sendable 표기 버전차를 흡수하기 위한 것.
    private let client: SupabaseClient
    private let configuration: Configuration

    public init(client: SupabaseClient, configuration: Configuration) {
        self.client = client
        self.configuration = configuration
    }

    // MARK: - AuthBackend

    public var currentIdentity: AuthIdentity? {
        get async {
            guard let session = try? await client.auth.session else { return nil }
            return SupabaseAuthMapping.identity(from: session)
        }
    }

    public var events: AsyncStream<(event: AuthEvent, identity: AuthIdentity?)> {
        AsyncStream { continuation in
            let task = Task { [client, logger] in
                for await (rawEvent, rawSession) in client.auth.authStateChanges {
                    guard let event = SupabaseAuthMapping.authEvent(from: rawEvent) else { continue }
                    let identity = rawSession.map { SupabaseAuthMapping.identity(from: $0) }
                    logger.debug("authEvent: \(event.rawValue), identity=\(identity?.uid ?? "없음")")
                    continuation.yield((event, identity))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func exchange(_ credential: AuthCredential) async throws -> AuthIdentity {

        let session: Session

        do {
            switch credential {
            case let .apple(idToken, rawNonce, _, _, _):
                session = try await client.auth.signInWithIdToken(
                    credentials: OpenIDConnectCredentials(
                        provider: .apple,
                        idToken: idToken,
                        nonce: rawNonce
                    )
                )

            case let .google(idToken, _):
                // nonce 생략 — Supabase Google provider 에 "skip nonce check" 가 켜져 있음.
                session = try await client.auth.signInWithIdToken(
                    credentials: OpenIDConnectCredentials(
                        provider: .google,
                        idToken: idToken
                    )
                )

            case let .kakao(idToken, rawNonce):
                session = try await exchangeKakao(idToken: idToken, rawNonce: rawNonce)
            }

        } catch let error as AuthKitError {
            throw error

        } catch let error as HTTPError {
            logger.error("signInWithIdToken HTTP \(error.response.statusCode): \(error.localizedDescription)")
            throw AuthKitError.backendHTTP(
                statusCode: error.response.statusCode,
                message: error.localizedDescription
            )

        } catch {
            logger.error("signInWithIdToken 실패: \(error.localizedDescription)")
            throw AuthKitError.backendNetwork(underlying: error)
        }

        return SupabaseAuthMapping.identity(from: session, provider: credential.provider)
    }

    // supabase-swift 의 Auth 모듈에도 SignOutScope 가 있어 모듈 한정이 필요하다.
    public func signOut(scope: AuthKit.SignOutScope) async throws {
        do {
            try await client.auth.signOut(scope: scope == .global ? .global : .local)

        } catch let error as HTTPError {
            throw AuthKitError.backendHTTP(
                statusCode: error.response.statusCode,
                message: error.localizedDescription
            )

        } catch {
            throw AuthKitError.backendNetwork(underlying: error)
        }
    }

    public var accessToken: String? {
        get async {
            try? await client.auth.session.accessToken
        }
    }

    // MARK: - Kakao (GoTrue REST 우회)

    private func exchangeKakao(idToken: String, rawNonce: String) async throws -> Session {

        let grant = try await KakaoIdTokenGrant.exchange(
            idToken: idToken,
            rawNonce: rawNonce,
            supabaseURL: configuration.supabaseURL,
            apiKey: configuration.apiKey,
            additionalHeaders: configuration.additionalHeaders
        )

        // setSession 이 세션 저장 + authStateChanges 이벤트 방출까지 처리
        do {
            return try await client.auth.setSession(
                accessToken: grant.accessToken,
                refreshToken: grant.refreshToken
            )
        } catch let error as HTTPError {
            logger.error("setSession HTTP \(error.response.statusCode): \(error.localizedDescription)")
            throw AuthKitError.backendHTTP(
                statusCode: error.response.statusCode,
                message: error.localizedDescription
            )
        } catch {
            logger.error("setSession 실패: \(error.localizedDescription)")
            throw AuthKitError.backendNetwork(underlying: error)
        }
    }
}
