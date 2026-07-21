//
//  KakaoIdTokenGrantTests.swift
//  AppFoundation / AuthKitSupabaseTests
//
//  URLProtocol 스텁으로 요청 형태와 에러 매핑을 검증한다.
//  URLProtocol 핸들러가 전역 상태라 suite 를 직렬화한다.
//

import Foundation
import Testing
@testable import AuthKit
@testable import AuthKitSupabase

@Suite("KakaoIdTokenGrant", .serialized)
struct KakaoIdTokenGrantTests {

    private static let supabaseURL = URL(string: "https://example.supabase.co")!

    private static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    private static func exchange() async throws -> KakaoIdTokenGrant.TokenPair {
        try await KakaoIdTokenGrant.exchange(
            idToken: "test-id-token",
            rawNonce: "raw-nonce",
            supabaseURL: supabaseURL,
            apiKey: "test-api-key",
            additionalHeaders: ["x-device-id": "device-1"],
            session: makeSession()
        )
    }

    @Test("성공 — 요청 형태(URL·메서드·헤더·body)와 토큰 디코드")
    func successShape() async throws {
        StubURLProtocol.handler = { request in
            // URL: /auth/v1/token?grant_type=id_token
            let url = try #require(request.url)
            #expect(url.path.hasSuffix("/auth/v1/token"))
            #expect(url.query == "grant_type=id_token")
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "apikey") == "test-api-key")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            #expect(request.value(forHTTPHeaderField: "x-device-id") == "device-1")

            let bodyData = try #require(request.bodyData)
            let body = try #require(
                try JSONSerialization.jsonObject(with: bodyData) as? [String: String]
            )
            #expect(body["provider"] == "kakao")
            #expect(body["id_token"] == "test-id-token")
            #expect(body["nonce"] == "raw-nonce") // GoTrue 에는 raw — SDK 에 준 해시가 아님

            return (200, #"{"access_token":"at-1","refresh_token":"rt-1"}"#)
        }

        let pair = try await Self.exchange()
        #expect(pair == .init(accessToken: "at-1", refreshToken: "rt-1"))
    }

    @Test("4xx → backendHTTP(statusCode:message:)")
    func httpErrorMapping() async {
        StubURLProtocol.handler = { _ in (400, #"{"error":"invalid_grant"}"#) }

        do {
            _ = try await Self.exchange()
            Issue.record("에러가 throw 되지 않음")
        } catch let AuthKitError.backendHTTP(statusCode, message) {
            #expect(statusCode == 400)
            #expect(message.contains("invalid_grant"))
        } catch {
            Issue.record("backendHTTP 가 아닌 에러: \(error)")
        }
    }

    @Test("디코드 불가 body → unexpectedResponse")
    func decodeFailureMapping() async {
        StubURLProtocol.handler = { _ in (200, "<html>not json</html>") }

        do {
            _ = try await Self.exchange()
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
}

// MARK: - URLProtocol 스텁

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
