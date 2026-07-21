//
//  RESTAuthBackendTests.swift
//  AppFoundation / AuthKitTests
//
//  URLProtocol 스텁 + InMemorySessionStore 로 표준 계약 형태·에러 매핑·
//  세션 저장·이벤트 방출을 검증한다. URLProtocol 핸들러가 전역 상태라
//  suite 를 직렬화한다.
//

import Foundation
import Testing
@testable import AuthKit

@Suite("RESTAuthBackend", .serialized)
struct RESTAuthBackendTests {

    private static let exchangeURL = URL(string: "https://api.example.com/auth/exchange")!
    private static let signOutURL = URL(string: "https://api.example.com/auth/signout")!

    private static let sessionJSON =
        #"{"access_token":"at-1","refresh_token":"rt-1","uid":"user-1","email":"user@example.com"}"#

    private static func makeBackend(
        store: InMemorySessionStore = InMemorySessionStore(),
        signOutURL: URL? = nil
    ) -> RESTAuthBackend {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return RESTAuthBackend(
            configuration: .init(
                exchangeURL: exchangeURL,
                signOutURL: signOutURL,
                additionalHeaders: ["x-api-key": "key-1"]
            ),
            store: store,
            urlSession: URLSession(configuration: config)
        )
    }

    // MARK: - 표준 계약: 요청 형태

    @Test("apple/kakao — body 에 provider·id_token·nonce(raw)가 실린다")
    func exchangeBodyWithNonce() async throws {
        StubURLProtocol.handler = { request in
            #expect(request.url == Self.exchangeURL)
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            #expect(request.value(forHTTPHeaderField: "x-api-key") == "key-1")

            let bodyData = try #require(request.bodyData)
            let body = try #require(
                try JSONSerialization.jsonObject(with: bodyData) as? [String: String]
            )
            #expect(body == [
                "provider": "kakao",
                "id_token": "id-token-1",
                "nonce": "raw-nonce",
            ])
            return (200, Self.sessionJSON)
        }

        _ = try await Self.makeBackend()
            .exchange(.kakao(idToken: "id-token-1", rawNonce: "raw-nonce"))
    }

    @Test("google — body 에 id_token·access_token 이 실린다 (nonce 없음)")
    func exchangeBodyGoogle() async throws {
        StubURLProtocol.handler = { request in
            let bodyData = try #require(request.bodyData)
            let body = try #require(
                try JSONSerialization.jsonObject(with: bodyData) as? [String: String]
            )
            #expect(body == [
                "provider": "google",
                "id_token": "id-token-1",
                "access_token": "access-1",
            ])
            return (200, Self.sessionJSON)
        }

        _ = try await Self.makeBackend()
            .exchange(.google(idToken: "id-token-1", accessToken: "access-1"))
    }

    @Test("custom — parameters 가 body 에 병합된다")
    func exchangeBodyCustomMergesParameters() async throws {
        StubURLProtocol.handler = { request in
            let bodyData = try #require(request.bodyData)
            let body = try #require(
                try JSONSerialization.jsonObject(with: bodyData) as? [String: String]
            )
            #expect(body == [
                "provider": "naver",
                "code": "authz-code",
                "state": "state-1",
            ])
            return (200, Self.sessionJSON)
        }

        _ = try await Self.makeBackend().exchange(.custom(
            provider: SocialProvider(rawValue: "naver"),
            parameters: ["code": "authz-code", "state": "state-1"]
        ))
    }

    // MARK: - 성공 경로: 저장·identity·토큰

    @Test("교환 성공 — store 저장 + accessToken/currentIdentity 반영")
    func exchangeSavesSession() async throws {
        StubURLProtocol.handler = { _ in (200, Self.sessionJSON) }

        let store = InMemorySessionStore()
        let backend = Self.makeBackend(store: store)

        let identity = try await backend.exchange(.kakao(idToken: "t", rawNonce: "n"))

        #expect(identity == AuthIdentity(uid: "user-1", provider: .kakao, email: "user@example.com"))
        #expect(store.load()?.accessToken == "at-1")
        #expect(await backend.accessToken == "at-1")
        #expect(await backend.currentIdentity?.uid == "user-1")
    }

    // MARK: - 에러 매핑

    @Test("4xx → backendHTTP(statusCode:message:), 세션 미저장")
    func httpErrorMapping() async {
        StubURLProtocol.handler = { _ in (401, #"{"error":"invalid_token"}"#) }

        let store = InMemorySessionStore()
        do {
            _ = try await Self.makeBackend(store: store)
                .exchange(.kakao(idToken: "t", rawNonce: "n"))
            Issue.record("에러가 throw 되지 않음")
        } catch let AuthKitError.backendHTTP(statusCode, message) {
            #expect(statusCode == 401)
            #expect(message.contains("invalid_token"))
        } catch {
            Issue.record("backendHTTP 가 아닌 에러: \(error)")
        }
        #expect(store.load() == nil)
    }

    @Test("디코드 불가 body → unexpectedResponse")
    func decodeFailureMapping() async {
        StubURLProtocol.handler = { _ in (200, "<html>not json</html>") }

        do {
            _ = try await Self.makeBackend()
                .exchange(.kakao(idToken: "t", rawNonce: "n"))
            Issue.record("에러가 throw 되지 않음")
        } catch let error as AuthKitError {
            guard case .unexpectedResponse = error else {
                Issue.record("unexpectedResponse 가 아닌 에러: \(error)")
                return
            }
        } catch {
            Issue.record("AuthKitError 가 아닌 에러: \(error)")
        }
    }

    // MARK: - signOut

    @Test("signOut(URL 없음) — 요청 없이 store 만 비운다")
    func signOutLocalOnly() async throws {
        StubURLProtocol.handler = { _ in
            Issue.record("signOutURL 이 없는데 요청이 발행됨")
            return (200, "{}")
        }

        let store = InMemorySessionStore(
            session: RESTSession(accessToken: "at-1", uid: "user-1")
        )
        try await Self.makeBackend(store: store).signOut(scope: .local)

        #expect(store.load() == nil)
    }

    @Test("signOut(URL 설정) — Bearer·scope 요청 발행 후 store 를 비운다")
    func signOutCallsServer() async throws {
        StubURLProtocol.handler = { request in
            #expect(request.url == Self.signOutURL)
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer at-1")

            let bodyData = try #require(request.bodyData)
            let body = try #require(
                try JSONSerialization.jsonObject(with: bodyData) as? [String: String]
            )
            #expect(body == ["scope": "global"])
            return (200, "{}")
        }

        let store = InMemorySessionStore(
            session: RESTSession(accessToken: "at-1", uid: "user-1")
        )
        try await Self.makeBackend(store: store, signOutURL: Self.signOutURL)
            .signOut(scope: .global)

        #expect(store.load() == nil)
    }

    @Test("signOut 서버 실패 — throw 되고 로컬 세션은 유지된다")
    func signOutServerFailureKeepsSession() async {
        StubURLProtocol.handler = { _ in (500, #"{"error":"boom"}"#) }

        let store = InMemorySessionStore(
            session: RESTSession(accessToken: "at-1", uid: "user-1")
        )
        do {
            try await Self.makeBackend(store: store, signOutURL: Self.signOutURL)
                .signOut(scope: .local)
            Issue.record("에러가 throw 되지 않음")
        } catch let AuthKitError.backendHTTP(statusCode, _) {
            #expect(statusCode == 500)
        } catch {
            Issue.record("backendHTTP 가 아닌 에러: \(error)")
        }
        #expect(store.load() != nil)
    }

    // MARK: - 이벤트

    @Test("events — 구독 시작 시 initialSessionLoaded, 교환 후 signedIn, signOut 후 signedOut")
    func eventsLifecycle() async throws {
        StubURLProtocol.handler = { _ in (200, Self.sessionJSON) }

        let backend = Self.makeBackend()
        var iterator = backend.events.makeAsyncIterator()

        // 저장 세션 없음 → identity nil 로 초기 이벤트
        let initial = await iterator.next()
        #expect(initial?.event == .initialSessionLoaded)
        #expect(initial?.identity == nil)

        _ = try await backend.exchange(.kakao(idToken: "t", rawNonce: "n"))
        let signedIn = await iterator.next()
        #expect(signedIn?.event == .signedIn)
        #expect(signedIn?.identity?.uid == "user-1")

        try await backend.signOut(scope: .local)
        let signedOut = await iterator.next()
        #expect(signedOut?.event == .signedOut)
        #expect(signedOut?.identity == nil)
    }
}

// MARK: - URLProtocol 스텁 (KakaoIdTokenGrantTests 와 동일 패턴)

final class StubURLProtocol: URLProtocol {

    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (Int, String))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }

        do {
            let (statusCode, body) = try handler(request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

extension URLRequest {
    /// URLProtocol 로 들어온 요청은 httpBody 가 stream 으로 바뀌어 있을 수 있다.
    var bodyData: Data? {
        if let httpBody { return httpBody }
        guard let stream = httpBodyStream else { return nil }

        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            guard read > 0 else { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
