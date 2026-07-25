//
//  TestSupport.swift
//  AppFoundation / APIKitSupabaseTests
//
//  실네트워크·키체인 접근 없는 테스트 픽스처. AuthKitSupabaseTests 와 같은 철학 —
//  SDK 를 실제로 태우지 않고 kit 이 소유한 라우팅·매핑 로직만 검증한다.
//

import Foundation
import APIKit
@testable import APIKitSupabase
import Supabase

enum TestSupport {

    /// `(code, message)` 훅만 쓰는 픽스처.
    static func makeAPIClient(
        mapServerError: (@Sendable (String, String) -> (any Error)?)? = nil
    ) -> SupabaseAPIClient {
        guard let mapServerError else {
            return SupabaseAPIClient(
                client: makeSupabaseClient(),
                userIDProvider: StubUserIDProvider()
            )
        }
        return SupabaseAPIClient.withSimpleErrorMapping(
            client: makeSupabaseClient(),
            userIDProvider: StubUserIDProvider(),
            mapServerError: mapServerError
        )
    }

    /// 부가 필드(`ServerErrorDetails`)까지 받는 훅 픽스처.
    static func makeAPIClient(
        mapServerErrorWithDetails: @escaping @Sendable (String, String, ServerErrorDetails?) -> (any Error)?
    ) -> SupabaseAPIClient {
        SupabaseAPIClient(
            client: makeSupabaseClient(),
            userIDProvider: StubUserIDProvider(),
            mapServerError: mapServerErrorWithDetails
        )
    }

    /// 네트워크를 타기 전에 가드가 끊는 경로만 테스트하므로 더미 설정으로 충분하다.
    /// 키체인 접근을 피하려고 auth storage 를 인메모리로, 토큰 자동 갱신은 끈다.
    static func makeSupabaseClient() -> SupabaseClient {
        SupabaseClient(
            supabaseURL: URL(string: "https://example.supabase.co")!,
            supabaseKey: "test-key",
            options: SupabaseClientOptions(
                auth: .init(storage: InMemoryAuthStorage(), autoRefreshToken: false)
            )
        )
    }
}

struct StubUserIDProvider: CurrentUserIDProviding {
    func currentUserID() async throws -> String { "user-1" }
}

final class InMemoryAuthStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]

    func store(key: String, value: Data) throws {
        lock.withLock { values[key] = value }
    }

    func retrieve(key: String) throws -> Data? {
        lock.withLock { values[key] }
    }

    func remove(key: String) throws {
        lock.withLock { values[key] = nil }
    }
}

/// transport 만 지정하는 평범한 엔드포인트 — Database/Storage/Realtime 프로토콜 미준수.
struct PlainEndpoint: Endpoint {
    let name: String
    let transport: APIKit.EndpointTransport
    var method: APIKit.HTTPMethod = .post
    var task: EndpointTask = .plain
}

/// SDK 없이 이벤트를 방출하는 realtime 엔드포인트 — stream 라우팅 검증용.
struct StubRealtimeEndpoint: RealtimeEndpoint {
    let name = "watch_rows"
    let transport = APIKit.EndpointTransport.realtime
    let method = APIKit.HTTPMethod.get
    let task = EndpointTask.plain
    let events: [Int]

    func executeStream<Event: Decodable & Sendable>(
        context: RealtimeContext,
        event: Event.Type
    ) async throws -> AsyncThrowingStream<Event, Error> {
        AsyncThrowingStream { continuation in
            for value in events {
                if let typed = value as? Event {
                    continuation.yield(typed)
                }
            }
            continuation.finish()
        }
    }
}
