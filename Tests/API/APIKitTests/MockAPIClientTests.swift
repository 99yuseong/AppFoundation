//
//  MockAPIClientTests.swift
//  AppFoundation / APIKitTests
//

import Foundation
import Testing
@testable import APIKit

@Suite("MockAPIClient")
struct MockAPIClientTests {

    struct Row: Decodable, Equatable {
        let value: Int
    }

    @Test("지정 JSON 을 Response 로 디코드 + 호출 순서 기록")
    func decodesConfiguredResponse() async throws {
        let key = EndpointKey(name: "fetch_row", transport: .edgeFunction)
        let mock = MockAPIClient(responses: [key: #"{"value":1}"#])

        let row: Row = try await mock.request(TestEndpoint(name: "fetch_row", transport: .edgeFunction))

        #expect(row == Row(value: 1))
        #expect(mock.calledActions == [key])
    }

    @Test("rpc — 실구현과 같은 배열-first 디코드")
    func rpcArrayFirst() async throws {
        let key = EndpointKey(name: "session_init", transport: .rpc)
        let mock = MockAPIClient(responses: [key: #"[{"value":2}]"#])

        let row: Row = try await mock.request(TestEndpoint(name: "session_init", transport: .rpc))

        #expect(row == Row(value: 2))
    }

    @Test("rpc — 빈 배열은 실구현과 같은 empty_rpc_result")
    func rpcEmptyArray() async {
        let key = EndpointKey(name: "session_init", transport: .rpc)
        let mock = MockAPIClient(responses: [key: "[]"])

        await #expect(throws: APIError.server(code: "empty_rpc_result", message: "session_init 이 빈 결과 반환")) {
            let _: Row = try await mock.request(TestEndpoint(name: "session_init", transport: .rpc))
        }
    }

    @Test("EmptyResponse — 응답 미지정이어도 성공")
    func emptyResponseShortcut() async throws {
        let mock = MockAPIClient()

        let _: EmptyResponse = try await mock.request(TestEndpoint(name: "update_row", transport: .database))

        #expect(mock.calledActions == [EndpointKey(name: "update_row", transport: .database)])
    }

    @Test("failure 지정 시 그대로 throw")
    func failurePropagates() async {
        let mock = MockAPIClient(failure: APIError.unauthorized(message: "만료"))

        await #expect(throws: APIError.unauthorized(message: "만료")) {
            let _: Row = try await mock.request(TestEndpoint(name: "x", transport: .edgeFunction))
        }
    }

    @Test("응답 미지정 — no_mock 에러")
    func missingResponse() async {
        let mock = MockAPIClient()

        await #expect(throws: APIError.server(code: "no_mock", message: "x 응답 미지정")) {
            let _: Row = try await mock.request(TestEndpoint(name: "x", transport: .edgeFunction))
        }
    }

    @Test("stream — 이벤트 배열을 순서대로 방출 후 종료")
    func streamYieldsEvents() async throws {
        let key = EndpointKey(name: "watch_rows", transport: .realtime)
        let mock = MockAPIClient(responses: [key: "[1,2,3]"])

        let stream: AsyncThrowingStream<Int, Error> = try await mock.stream(
            TestEndpoint(name: "watch_rows", transport: .realtime)
        )

        var received: [Int] = []
        for try await event in stream {
            received.append(event)
        }
        #expect(received == [1, 2, 3])
        #expect(mock.calledActions == [key])
    }
}
