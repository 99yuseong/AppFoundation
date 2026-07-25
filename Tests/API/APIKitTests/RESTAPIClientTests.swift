//
//  RESTAPIClientTests.swift
//  AppFoundation / APIKitTests
//
//  URLProtocol 스텁으로 URLRequest 조립(method/query/json/upload)·상태코드 매핑·
//  envelope/raw 분기·adapt 훅을 검증한다. URLProtocol 핸들러가 전역 상태라
//  suite 를 직렬화한다.
//

import Foundation
import Testing
@testable import APIKit

@Suite("RESTAPIClient", .serialized)
struct RESTAPIClientTests {

    private static let baseURL = URL(string: "https://api.example.com/v1")!

    private struct UserResponse: Decodable, Equatable {
        let id: String
    }

    private enum DomainError: Error, Equatable {
        case custom(String)
    }

    private static func makeClient(
        defaultHeaders: [String: String] = [:],
        adapt: (@Sendable (URLRequest) async throws -> URLRequest)? = nil,
        unwrapping: RESTAPIClient.ResponseUnwrapping = .raw,
        mapServerError: (@Sendable (String, String) -> (any Error)?)? = nil
    ) -> RESTAPIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubRESTURLProtocol.self]
        let session = URLSession(configuration: config)

        guard let mapServerError else {
            return RESTAPIClient(
                baseURL: baseURL,
                session: session,
                defaultHeaders: defaultHeaders,
                adapt: adapt,
                unwrapping: unwrapping
            )
        }
        return RESTAPIClient.withSimpleErrorMapping(
            baseURL: baseURL,
            session: session,
            defaultHeaders: defaultHeaders,
            adapt: adapt,
            unwrapping: unwrapping,
            mapServerError: mapServerError
        )
    }

    // MARK: - 요청 조립

    @Test("GET + .query — path 는 name, 쿼리·기본 헤더가 실리고 body 없음")
    func getWithQuery() async throws {
        StubRESTURLProtocol.handler = { request in
            #expect(request.url?.absoluteString == "https://api.example.com/v1/users/me?page=2")
            #expect(request.httpMethod == "GET")
            #expect(request.value(forHTTPHeaderField: "x-api-key") == "key-1")
            #expect(request.bodyData == nil)
            return (200, #"{"id":"user-1"}"#)
        }

        let response: UserResponse = try await Self.makeClient(defaultHeaders: ["x-api-key": "key-1"])
            .request(TestEndpoint(
                name: "users/me",
                transport: .http,
                method: .get,
                task: .query([URLQueryItem(name: "page", value: "2")])
            ))

        #expect(response == UserResponse(id: "user-1"))
    }

    @Test("POST + .json — 선언한 verb 로 JSON body·Content-Type 이 실린다")
    func postWithJSONBody() async throws {
        struct Body: Encodable, Sendable {
            let title: String
        }

        StubRESTURLProtocol.handler = { request in
            #expect(request.url?.absoluteString == "https://api.example.com/v1/posts")
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

            let bodyData = try #require(request.bodyData)
            let body = try #require(
                try JSONSerialization.jsonObject(with: bodyData) as? [String: String]
            )
            #expect(body == ["title": "hello"])
            return (200, #"{"id":"post-1"}"#)
        }

        let _: UserResponse = try await Self.makeClient()
            .request(TestEndpoint(
                name: "posts",
                transport: .http,
                method: .post,
                task: .json(Body(title: "hello"))
            ))
    }

    @Test(".upload — 바이너리 body 와 선언한 contentType 이 실린다")
    func uploadTask() async throws {
        let payload = Data([0x89, 0x50, 0x4E, 0x47])

        StubRESTURLProtocol.handler = { request in
            #expect(request.httpMethod == "PUT")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "image/png")
            #expect(request.bodyData == payload)
            return (200, "{}")
        }

        let _: EmptyResponse = try await Self.makeClient()
            .request(TestEndpoint(
                name: "avatar",
                transport: .http,
                method: .put,
                task: .upload(data: payload, contentType: "image/png")
            ))
    }

    @Test("adapt 훅 — 전송 직전 요청 가공(토큰 주입)이 반영된다")
    func adaptHook() async throws {
        StubRESTURLProtocol.handler = { request in
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token-1")
            return (200, #"{"id":"user-1"}"#)
        }

        let _: UserResponse = try await Self.makeClient(adapt: { request in
            var adapted = request
            adapted.setValue("Bearer token-1", forHTTPHeaderField: "Authorization")
            return adapted
        })
        .request(TestEndpoint(name: "users/me", transport: .http, method: .get))
    }

    // MARK: - 응답 해석

    @Test(".envelope — {ok:true,data} 의 data 만 디코딩한다")
    func envelopeUnwrapping() async throws {
        StubRESTURLProtocol.handler = { _ in
            (200, #"{"ok":true,"data":{"id":"user-1"}}"#)
        }

        let response: UserResponse = try await Self.makeClient(unwrapping: .envelope)
            .request(TestEndpoint(name: "users/me", transport: .http, method: .get))

        #expect(response == UserResponse(id: "user-1"))
    }

    @Test("본문 없는 2xx + EmptyResponse — 디코딩 없이 통과한다")
    func emptyBodySuccess() async throws {
        StubRESTURLProtocol.handler = { _ in (204, "") }

        let _: EmptyResponse = try await Self.makeClient()
            .request(TestEndpoint(name: "posts/1", transport: .http, method: .delete))
    }

    // MARK: - 에러 매핑

    @Test("실패 본문이 envelope 계약 — code 가 훅을 거쳐 도메인 에러로 매핑된다")
    func envelopeErrorWithHook() async throws {
        StubRESTURLProtocol.handler = { _ in
            (400, #"{"ok":false,"error":{"code":"title_too_long","message":"제목 초과"}}"#)
        }

        let client = Self.makeClient(mapServerError: { code, message in
            code == "title_too_long" ? DomainError.custom(message) : nil
        })

        await #expect(throws: DomainError.custom("제목 초과")) {
            let _: UserResponse = try await client
                .request(TestEndpoint(name: "posts", transport: .http, method: .post))
        }
    }

    @Test("실패 본문이 envelope 계약 + 훅 없음 — 중립 APIError 로 폴백")
    func envelopeErrorNeutralFallback() async throws {
        StubRESTURLProtocol.handler = { _ in
            (401, #"{"ok":false,"error":{"code":"unauthorized","message":"토큰 만료"}}"#)
        }

        await #expect(throws: APIError.unauthorized(message: "토큰 만료")) {
            let _: UserResponse = try await Self.makeClient()
                .request(TestEndpoint(name: "users/me", transport: .http, method: .get))
        }
    }

    @Test("규약 밖 401 본문 — unauthorized 로 매핑")
    func plainUnauthorized() async throws {
        StubRESTURLProtocol.handler = { _ in (401, "denied") }

        await #expect(throws: APIError.unauthorized(message: "denied")) {
            let _: UserResponse = try await Self.makeClient()
                .request(TestEndpoint(name: "users/me", transport: .http, method: .get))
        }
    }

    @Test("규약 밖 5xx 본문 — http_<status> 코드의 중립 에러")
    func plainServerError() async throws {
        StubRESTURLProtocol.handler = { _ in (503, "unavailable") }

        await #expect(throws: APIError.server(code: "http_503", message: "unavailable")) {
            let _: UserResponse = try await Self.makeClient()
                .request(TestEndpoint(name: "users/me", transport: .http, method: .get))
        }
    }

    // MARK: - 진입점 방어

    @Test("비-http transport — 요청 발행 없이 unsupported_transport")
    func rejectsNonHTTPTransport() async throws {
        StubRESTURLProtocol.handler = { _ in
            Issue.record("비-http transport 인데 요청이 발행됨")
            return (200, "{}")
        }

        await #expect(throws: APIError.server(
            code: "unsupported_transport",
            message: "submit_report 의 transport(rpc)를 RESTAPIClient 가 지원하지 않음"
        )) {
            let _: UserResponse = try await Self.makeClient()
                .request(TestEndpoint(name: "submit_report", transport: .rpc))
        }
    }

    @Test("stream — v1 미지원 에러")
    func streamUnsupported() async throws {
        await #expect(throws: APIError.self) {
            let _: AsyncThrowingStream<UserResponse, Error> = try await Self.makeClient()
                .stream(TestEndpoint(name: "feed", transport: .http, method: .get))
        }
    }
}

// MARK: - URLProtocol 스텁 (AuthKitTests/RESTAuthBackendTests 와 동일 패턴 —
// 테스트 타깃이 달라 import 할 수 없어 복제한다)

final class StubRESTURLProtocol: URLProtocol {

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
