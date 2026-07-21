//
//  RESTAuthBackend.swift
//  AppFoundation / AuthKitREST
//
//  일반(자체) 서버용 AuthBackend — 외부 의존 zero. kit 이 정의한 표준 계약을
//  앱 서버가 구현하면 바로 붙는다(docs/auth/08-custom-backend.md 에 서버 스펙).
//
//  표준 계약:
//    POST {exchangeURL}
//      body: {"provider": "...", "id_token": "...", "nonce"?: raw, "access_token"?: "..."}
//      (.custom credential 은 parameters 가 body 에 병합된다)
//      응답: {"access_token": "...", "refresh_token"?: "...", "uid": "...", "email"?: "..."}
//    POST {signOutURL}  (설정 시)
//      헤더: Authorization: Bearer <access_token> / body: {"scope": "local"|"global"}
//
//  계약이 다른 서버는 Configuration 의 encode/decode 클로저로 오버라이드한다.
//
//  범위: access token 자동 갱신은 v1 범위 밖이다 — 만료가 있는 토큰을 쓰는 앱은
//  `AuthBackend` 를 직접 구현한다(08 문서 참조).
//

import AuthKit
import Foundation
import os

public final class RESTAuthBackend: AuthBackend, @unchecked Sendable {

    public struct Configuration: Sendable {

        /// credential ↔ 세션 교환 엔드포인트.
        public let exchangeURL: URL
        /// nil 이면 signOut 은 로컬 세션 삭제만 한다.
        public var signOutURL: URL?
        /// 모든 요청에 실을 추가 헤더(x-api-key 등).
        public var additionalHeaders: [String: String]
        /// 계약이 다른 서버용 오버라이드 — nil 이면 표준 계약으로 인코드한다.
        public var encodeExchangeBody: (@Sendable (AuthCredential) throws -> Data)?
        /// 계약이 다른 서버용 오버라이드 — nil 이면 표준 계약으로 디코드한다.
        public var decodeExchangeResponse: (@Sendable (Data) throws -> RESTSession)?

        public init(
            exchangeURL: URL,
            signOutURL: URL? = nil,
            additionalHeaders: [String: String] = [:],
            encodeExchangeBody: (@Sendable (AuthCredential) throws -> Data)? = nil,
            decodeExchangeResponse: (@Sendable (Data) throws -> RESTSession)? = nil
        ) {
            self.exchangeURL = exchangeURL
            self.signOutURL = signOutURL
            self.additionalHeaders = additionalHeaders
            self.encodeExchangeBody = encodeExchangeBody
            self.decodeExchangeResponse = decodeExchangeResponse
        }
    }

    private let logger = Logger(subsystem: "AppFoundation", category: "AuthKit.REST")

    private let configuration: Configuration
    private let store: any SessionStoring
    private let urlSession: URLSession

    // 이벤트 브로드캐스트 — lock 이 continuation 목록을 보호한다.
    private let lock = NSLock()
    private var continuations: [UUID: AsyncStream<(event: AuthEvent, identity: AuthIdentity?)>.Continuation] = [:]

    public init(
        configuration: Configuration,
        store: any SessionStoring = KeychainSessionStore(),
        urlSession: URLSession = .shared
    ) {
        self.configuration = configuration
        self.store = store
        self.urlSession = urlSession
    }

    // MARK: - AuthBackend

    public var currentIdentity: AuthIdentity? {
        get async { store.load().map(Self.identity(from:)) }
    }

    public var events: AsyncStream<(event: AuthEvent, identity: AuthIdentity?)> {
        AsyncStream { continuation in
            let id = UUID()
            lock.withLock { continuations[id] = continuation }
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                self.lock.withLock { self.continuations[id] = nil }
            }
            // 구독 시작 시 저장된 세션 상태를 1회 방출 — 앱 실행 시 자동 로그인 구동.
            continuation.yield((.initialSessionLoaded, store.load().map(Self.identity(from:))))
        }
    }

    public func exchange(_ credential: AuthCredential) async throws -> AuthIdentity {

        logger.debug("exchange(\(credential.provider.rawValue)) — \(self.configuration.exchangeURL)")

        var request = URLRequest(url: configuration.exchangeURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in configuration.additionalHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = try (configuration.encodeExchangeBody ?? Self.standardBody)(credential)

        let data = try await send(request)

        let session: RESTSession
        do {
            session = try (configuration.decodeExchangeResponse
                ?? { try JSONDecoder().decode(RESTSession.self, from: $0) })(data)
        } catch {
            throw AuthKitError.unexpectedResponse(
                message: "교환 응답 디코드 실패: \(error.localizedDescription)"
            )
        }

        store.save(session)

        let identity = AuthIdentity(
            uid: session.uid,
            provider: credential.provider,
            email: session.email
        )

        logger.info("✅ 세션 교환 성공 — uid=\(identity.uid)")
        broadcast(.signedIn, identity)

        return identity
    }

    public func signOut(scope: SignOutScope) async throws {

        if let signOutURL = configuration.signOutURL, let session = store.load() {
            var request = URLRequest(url: signOutURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            for (key, value) in configuration.additionalHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "scope": scope == .global ? "global" : "local"
            ])

            // 서버 실패는 삼키지 않는다 — 로컬 세션도 유지된 채 throw 된다.
            // (탈퇴 뒤 정리처럼 실패를 무시해야 하면 AuthService.endSession 을 쓴다)
            _ = try await send(request)
        }

        store.clear()
        logger.info("👋 REST 세션 종료")
        broadcast(.signedOut, nil)
    }

    public var accessToken: String? {
        get async { store.load()?.accessToken }
    }

    // MARK: - 표준 계약

    /// `{"provider", "id_token", "nonce"?, "access_token"?}` — .custom 은 parameters 병합.
    private static func standardBody(for credential: AuthCredential) throws -> Data {
        var body: [String: String] = ["provider": credential.provider.rawValue]

        switch credential {
        case let .apple(idToken, rawNonce, _, _, _):
            body["id_token"] = idToken
            body["nonce"] = rawNonce

        case let .google(idToken, accessToken):
            body["id_token"] = idToken
            body["access_token"] = accessToken

        case let .kakao(idToken, rawNonce):
            body["id_token"] = idToken
            body["nonce"] = rawNonce

        case let .custom(_, parameters):
            body.merge(parameters) { _, custom in custom }
        }

        return try JSONSerialization.data(withJSONObject: body)
    }

    private static func identity(from session: RESTSession) -> AuthIdentity {
        AuthIdentity(uid: session.uid, provider: nil, email: session.email)
    }

    // MARK: - HTTP

    private func send(_ request: URLRequest) async throws -> Data {

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            logger.error("REST 요청 네트워크 실패: \(error.localizedDescription)")
            throw AuthKitError.backendNetwork(underlying: error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AuthKitError.unexpectedResponse(message: "HTTP 응답이 아님")
        }

        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "no body"
            logger.error("REST HTTP \(http.statusCode): \(body)")
            throw AuthKitError.backendHTTP(statusCode: http.statusCode, message: body)
        }

        return data
    }

    private func broadcast(_ event: AuthEvent, _ identity: AuthIdentity?) {
        let targets = lock.withLock { Array(continuations.values) }
        for continuation in targets {
            continuation.yield((event, identity))
        }
    }
}
