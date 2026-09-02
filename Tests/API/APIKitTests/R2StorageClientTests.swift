//
//  R2StorageClientTests.swift
//  AppFoundation / APIKitTests
//
//  R2 티켓제 실행 — 업로드 2단계(서명 → PUT), public/private URL 분기, 서명 캐시,
//  에러 매핑. StubRESTURLProtocol(RESTAPIClientTests)을 재사용하며 핸들러가 전역
//  상태라 suite 를 직렬화한다.
//

import Foundation
import Testing
@testable import APIKit

@Suite("R2StorageClient", .serialized)
struct R2StorageClientTests {

    private static let workerURL = URL(string: "https://app-storage-sign.example.workers.dev")!

    private enum PrivateBucket: StorageBucket {
        static let bucketName = "private-b"
        static let isPublic = false
    }

    private enum PublicBucket: StorageBucket {
        static let bucketName = "public-b"
        static let isPublic = true
    }

    /// 요청 기록용 — 핸들러(@Sendable)가 캡처한다.
    private final class RequestLog: @unchecked Sendable {
        private let lock = NSLock()
        private var _requests: [URLRequest] = []
        var requests: [URLRequest] { lock.withLock { _requests } }
        func append(_ request: URLRequest) { lock.withLock { _requests.append(request) } }
    }

    private static func makeClient(
        publicBaseURLs: [String: URL] = [:],
        cache: SignedURLCache = SignedURLCache()
    ) -> R2StorageClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubRESTURLProtocol.self]
        let session = URLSession(configuration: config)
        return R2StorageClient(
            signer: WorkerR2Signer(
                workerURL: workerURL,
                tokenProvider: { "supabase-token" },
                session: session
            ),
            publicBaseURLs: publicBaseURLs,
            session: session,
            cache: cache
        )
    }

    // 와이어 계약 검증용 최소 디코딩 타입.
    private struct WireRequest: Decodable {
        struct Item: Decodable {
            let bucket: String
            let path: String
            let method: String
            let contentType: String?
            let expiresIn: Int
        }
        let items: [Item]
    }

    @Test("upload — 서명 요청(와이어 계약) 후 presigned PUT, 반환 path = 요청 path")
    func uploadTwoStep() async throws {
        let log = RequestLog()
        StubRESTURLProtocol.handler = { request in
            log.append(request)
            if request.url?.host == Self.workerURL.host {
                // 1단계 — Worker 서명 요청: 와이어 계약 검증
                #expect(request.httpMethod == "POST")
                #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer supabase-token")
                let body = try JSONDecoder().decode(WireRequest.self, from: request.bodyData ?? Data())
                #expect(body.items.count == 1)
                #expect(body.items.first?.bucket == "private-b")
                #expect(body.items.first?.path == "u1/a.jpg")
                #expect(body.items.first?.method == "PUT")
                #expect(body.items.first?.contentType == "image/jpeg")
                return (200, #"{"urls":[{"url":"https://acc.r2.cloudflarestorage.com/private-b/u1/a.jpg?X-Amz-Signature=sig","expiresAt":"2026-01-01T00:00:00Z"}]}"#)
            }
            // 2단계 — presigned PUT: 서명 URL 로 직접 전송, Content-Type 은 서명과 일치
            #expect(request.httpMethod == "PUT")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "image/jpeg")
            #expect(request.url?.query?.contains("X-Amz-Signature") == true)
            return (200, "")
        }
        defer { StubRESTURLProtocol.handler = nil }

        let path = try await Self.makeClient()
            .upload(Data("bytes".utf8), to: PrivateBucket.self, path: "u1/a.jpg", contentType: "image/jpeg")

        #expect(path == "u1/a.jpg")
        #expect(log.requests.count == 2)
    }

    @Test("public 버킷 — 네트워크 없이 커스텀 도메인 + path 조합")
    func publicURL() async throws {
        StubRESTURLProtocol.handler = { _ in
            Issue.record("public 버킷은 네트워크를 타면 안 된다")
            return (500, "{}")
        }
        defer { StubRESTURLProtocol.handler = nil }

        let url = try await Self.makeClient(publicBaseURLs: ["public-b": URL(string: "https://cdn.example.com")!])
            .url(for: PublicBucket.self, path: "u1/a.jpg")

        #expect(url.absoluteString == "https://cdn.example.com/u1/a.jpg")
    }

    @Test("public 버킷 — publicBaseURLs 미등록이면 조립 오류를 드러낸다")
    func publicURLMissingBase() async {
        StubRESTURLProtocol.handler = nil

        await #expect(throws: APIError.server(
            code: "missing_public_base_url",
            message: "public 버킷 public-b 의 publicBaseURLs 미등록 — R2StorageClient 조립 확인"
        )) {
            _ = try await Self.makeClient().url(for: PublicBucket.self, path: "p")
        }
    }

    @Test("private 버킷 — GET 서명 발급, 만료 전 재호출은 캐시로 왕복 1회 유지")
    func privateURLUsesCache() async throws {
        let log = RequestLog()
        StubRESTURLProtocol.handler = { request in
            log.append(request)
            let body = try JSONDecoder().decode(WireRequest.self, from: request.bodyData ?? Data())
            #expect(body.items.first?.method == "GET")
            #expect(body.items.first?.contentType == nil)
            #expect(body.items.first?.expiresIn == Int(PrivateBucket.signedURLExpiry))
            return (200, #"{"urls":[{"url":"https://acc.r2.cloudflarestorage.com/private-b/p?X-Amz-Signature=sig","expiresAt":"2026-01-01T00:00:00Z"}]}"#)
        }
        defer { StubRESTURLProtocol.handler = nil }

        let client = Self.makeClient()

        let first = try await client.url(for: PrivateBucket.self, path: "p")
        let second = try await client.url(for: PrivateBucket.self, path: "p")

        #expect(first == second)
        #expect(first.query?.contains("X-Amz-Signature") == true)
        #expect(log.requests.count == 1)   // 재발급 없음
    }

    @Test("서명 실패 — envelope 계약이면 중립 APIError 로 매핑")
    func signFailureMapsEnvelope() async {
        StubRESTURLProtocol.handler = { _ in
            (401, #"{"ok":false,"error":{"code":"unauthorized","message":"토큰 만료"}}"#)
        }
        defer { StubRESTURLProtocol.handler = nil }

        await #expect(throws: APIError.unauthorized(message: "토큰 만료")) {
            _ = try await Self.makeClient().url(for: PrivateBucket.self, path: "p")
        }
    }

    @Test("delete — DELETE 서명 요청 후 presigned DELETE, 없는 키(404)도 성공")
    func deleteTwoStep() async throws {
        let log = RequestLog()
        StubRESTURLProtocol.handler = { request in
            log.append(request)
            if request.url?.host == Self.workerURL.host {
                let body = try JSONDecoder().decode(WireRequest.self, from: request.bodyData ?? Data())
                #expect(body.items.first?.method == "DELETE")
                #expect(body.items.first?.path == "u1/old.jpg")
                #expect(body.items.first?.contentType == nil)
                return (200, #"{"urls":[{"url":"https://acc.r2.cloudflarestorage.com/private-b/u1/old.jpg?X-Amz-Signature=sig","expiresAt":"2026-01-01T00:00:00Z"}]}"#)
            }
            #expect(request.httpMethod == "DELETE")
            #expect(request.url?.query?.contains("X-Amz-Signature") == true)
            return (404, "")   // 이미 없는 키 — idempotent 요건상 성공으로 본다
        }
        defer { StubRESTURLProtocol.handler = nil }

        try await Self.makeClient().delete(from: PrivateBucket.self, path: "u1/old.jpg")

        #expect(log.requests.count == 2)
    }

    @Test("presigned DELETE 실패 — 상태코드 기반 중립 에러")
    func deleteFailure() async {
        StubRESTURLProtocol.handler = { request in
            if request.url?.host == Self.workerURL.host {
                return (200, #"{"urls":[{"url":"https://acc.r2.cloudflarestorage.com/private-b/p?X-Amz-Signature=sig","expiresAt":"2026-01-01T00:00:00Z"}]}"#)
            }
            return (403, "")
        }
        defer { StubRESTURLProtocol.handler = nil }

        await #expect(throws: APIError.server(
            code: "r2_delete_failed_403",
            message: "R2 삭제 실패 403 — private-b/p"
        )) {
            try await Self.makeClient().delete(from: PrivateBucket.self, path: "p")
        }
    }

    @Test("presigned PUT 실패 — 상태코드 기반 중립 에러")
    func uploadPUTFailure() async {
        StubRESTURLProtocol.handler = { request in
            if request.url?.host == Self.workerURL.host {
                return (200, #"{"urls":[{"url":"https://acc.r2.cloudflarestorage.com/private-b/p?X-Amz-Signature=sig","expiresAt":"2026-01-01T00:00:00Z"}]}"#)
            }
            return (403, "")
        }
        defer { StubRESTURLProtocol.handler = nil }

        await #expect(throws: APIError.server(
            code: "r2_upload_failed_403",
            message: "R2 업로드 실패 403 — private-b/p"
        )) {
            _ = try await Self.makeClient()
                .upload(Data(), to: PrivateBucket.self, path: "p", contentType: "image/jpeg")
        }
    }
}
