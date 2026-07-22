//
//  MockAPIClient.swift
//  AppFoundation / APIKit
//
//  엔드포인트별로 응답 JSON 을 미리 지정하는 APIClient 목. request 는 그 JSON 을
//  요청된 Response 로 디코딩한다 — 실제 서버→디코딩 경로를 그대로 태우면서 실서버는
//  없앤다. 호출된 엔드포인트 순서(`calledActions`)를 기록해 오케스트레이션을 검증한다.
//
//  kit 에 포함하는 이유: 사용 앱의 테스트가 픽스처를 재작성하지 않도록(`MockAuthService`
//  선례). Moya 처럼 엔드포인트 선언에 sampleData 를 두는 방식은 프로덕션 코드에
//  픽스처가 섞여 채택하지 않았다.
//

import Foundation

public final class MockAPIClient: APIClient, @unchecked Sendable {

    private let responses: [EndpointKey: String]
    private let failure: (any Error)?

    private let lock = NSLock()
    private var _calledActions: [EndpointKey] = []

    /// 호출된 엔드포인트 순서. 오케스트레이션 검증용.
    public var calledActions: [EndpointKey] {
        lock.withLock { _calledActions }
    }

    public init(responses: [EndpointKey: String] = [:], failure: (any Error)? = nil) {
        self.responses = responses
        self.failure = failure
    }

    public func request<Response: Decodable>(
        _ endpoint: some Endpoint
    ) async throws -> Response {
        let key = record(endpoint)
        if let failure { throw failure }
        if let empty = EmptyResponse() as? Response {
            return empty
        }
        guard let json = responses[key] else {
            throw APIError.server(code: "no_mock", message: "\(key.name) 응답 미지정")
        }
        let data = Data(json.utf8)
        // 실구현(RPC 의 배열-first 디코드, 빈 배열 → empty_rpc_result)과 같은 경로를 태운다.
        if key.transport == .rpc,
           let rows = try? JSONDecoder().decode([Response].self, from: data) {
            guard let first = rows.first else {
                throw APIError.server(code: "empty_rpc_result", message: "\(key.name) 이 빈 결과 반환")
            }
            return first
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }

    public func stream<Event: Decodable & Sendable>(
        _ endpoint: some Endpoint
    ) async throws -> AsyncThrowingStream<Event, Error> {
        let key = record(endpoint)
        if let failure { throw failure }
        guard let json = responses[key] else {
            throw APIError.server(code: "no_mock", message: "\(key.name) 응답 미지정")
        }
        // 지정 JSON 을 이벤트 배열로 디코딩해 순서대로 방출하고 종료한다.
        let events = try JSONDecoder().decode([Event].self, from: Data(json.utf8))
        return AsyncThrowingStream { continuation in
            for event in events {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }

    private func record(_ endpoint: some Endpoint) -> EndpointKey {
        let key = EndpointKey(endpoint)
        lock.withLock { _calledActions.append(key) }
        return key
    }
}
