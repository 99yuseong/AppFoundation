//
//  SupabaseStorageClientTests.swift
//  AppFoundation / APIKitSupabaseTests
//
//  StorageClient 중립 계약의 Supabase 실구현 — url() 의 public/private 분기와
//  서명 URL 캐시 경유(만료 전 재호출 = 왕복 0)를 검증한다. URLProtocol 핸들러가
//  전역 상태라 suite 를 직렬화한다 (RESTAPIClientTests 선례).
//

import Foundation
import Testing
import APIKit
@testable import APIKitSupabase
import Supabase

@Suite("SupabaseStorageClient", .serialized)
struct SupabaseStorageClientTests {

    private enum PrivateBucket: SupabaseBucket {
        static let bucketName = "private-b"
        static let isPublic = false
    }

    private enum PublicBucket: SupabaseBucket {
        static let bucketName = "public-b"
        static let isPublic = true
    }

    // 반환 타입 한정: supabase-swift 도 SupabaseStorageClient(client.storage 의 타입)를
    // 정의해, 양쪽을 import 하는 곳에서는 모듈 한정이 필요하다.
    private static func makeStorage(cache: SignedURLCache = SignedURLCache()) -> APIKitSupabase.SupabaseStorageClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubStorageURLProtocol.self]
        let client = SupabaseClient(
            supabaseURL: URL(string: "https://example.supabase.co")!,
            supabaseKey: "test-key",
            options: SupabaseClientOptions(
                auth: .init(storage: InMemoryAuthStorage(), autoRefreshToken: false),
                global: .init(session: URLSession(configuration: config))
            )
        )
        return APIKitSupabase.SupabaseStorageClient(client: client, cache: cache)
    }

    @Test("public 버킷 — 네트워크 없이 고정 공개 URL 조합")
    func publicURL() async throws {
        StubStorageURLProtocol.handler = { _ in
            Issue.record("public 버킷은 네트워크를 타면 안 된다")
            return (500, "{}")
        }
        defer { StubStorageURLProtocol.reset() }

        let url = try await Self.makeStorage().url(for: PublicBucket.self, path: "u1/a.jpg")

        #expect(url.absoluteString.hasSuffix("/object/public/public-b/u1/a.jpg"))
    }

    @Test("private 버킷 — 서명 URL 발급, 만료 전 재호출은 캐시로 왕복 1회 유지")
    func privateSignedURLUsesCache() async throws {
        StubStorageURLProtocol.handler = { request in
            #expect(request.url?.path.hasSuffix("/object/sign/private-b/u1/a.jpg") == true)
            return (200, #"{"signedURL":"/object/sign/private-b/u1/a.jpg?token=tkn-1"}"#)
        }
        defer { StubStorageURLProtocol.reset() }

        let storage = Self.makeStorage()

        let first = try await storage.url(for: PrivateBucket.self, path: "u1/a.jpg")
        #expect(first.absoluteString.contains("token=tkn-1"))
        #expect(StubStorageURLProtocol.requestCount == 1)

        let second = try await storage.url(for: PrivateBucket.self, path: "u1/a.jpg")
        #expect(second == first)
        #expect(StubStorageURLProtocol.requestCount == 1)   // 재발급 없음
    }

    @Test("private 버킷 — 캐시가 만료를 지나면 재발급")
    func privateSignedURLRefreshesAfterExpiry() async throws {
        StubStorageURLProtocol.handler = { _ in
            (200, #"{"signedURL":"/object/sign/private-b/p?token=tkn-\#(StubStorageURLProtocol.requestCount)"}"#)
        }
        defer { StubStorageURLProtocol.reset() }

        let clock = FixedClock()
        let storage = Self.makeStorage(cache: SignedURLCache(now: { clock.now }))

        _ = try await storage.url(for: PrivateBucket.self, path: "p")
        clock.now = clock.now.addingTimeInterval(PrivateBucket.signedURLExpiry)   // 만료 경과

        _ = try await storage.url(for: PrivateBucket.self, path: "p")
        #expect(StubStorageURLProtocol.requestCount == 2)
    }
}

/// 테스트 고정 시계.
private final class FixedClock: @unchecked Sendable {
    private let lock = NSLock()
    private var _now = Date(timeIntervalSince1970: 0)
    var now: Date {
        get { lock.withLock { _now } }
        set { lock.withLock { _now = newValue } }
    }
}

/// Storage API 스텁 (RESTAPIClientTests 의 StubRESTURLProtocol 과 같은 패턴 —
/// 타깃이 달라 공유하지 못하고 복제한다).
final class StubStorageURLProtocol: URLProtocol {

    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (Int, String))?
    nonisolated(unsafe) private static var _requestCount = 0
    private static let countLock = NSLock()

    static var requestCount: Int {
        countLock.withLock { _requestCount }
    }

    static func reset() {
        handler = nil
        countLock.withLock { _requestCount = 0 }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        Self.countLock.withLock { Self._requestCount += 1 }

        let (statusCode, body) = handler(request)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
