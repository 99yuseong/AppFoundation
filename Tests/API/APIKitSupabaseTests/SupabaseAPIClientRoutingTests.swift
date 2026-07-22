//
//  SupabaseAPIClientRoutingTests.swift
//  AppFoundation / APIKitSupabaseTests
//
//  transport/task 라우팅 가드 — 전부 네트워크를 타기 전에 끊기는 경로다.
//

import Foundation
import Testing
import APIKit
@testable import APIKitSupabase

@Suite("SupabaseAPIClient 라우팅")
struct SupabaseAPIClientRoutingTests {

    /// operation 이 던진 APIError.server 의 code 를 돌려준다 (미발생/타 에러는 nil).
    private func serverCode(from operation: () async throws -> Void) async -> String? {
        do {
            try await operation()
            return nil
        } catch let error as APIError {
            guard case .server(let code, _) = error else { return nil }
            return code
        } catch {
            return nil
        }
    }

    @Test(".database — DatabaseEndpoint 미준수면 invalid_database_endpoint")
    func databaseMismatch() async {
        let api = TestSupport.makeAPIClient()
        let code = await serverCode {
            let _: EmptyResponse = try await api.request(PlainEndpoint(name: "t", transport: .database))
        }
        #expect(code == "invalid_database_endpoint")
    }

    @Test(".storage — StorageEndpoint 미준수면 invalid_storage_endpoint")
    func storageMismatch() async {
        let api = TestSupport.makeAPIClient()
        let code = await serverCode {
            let _: EmptyResponse = try await api.request(PlainEndpoint(name: "t", transport: .storage))
        }
        #expect(code == "invalid_storage_endpoint")
    }

    @Test("EF/RPC — .json task 가 아니면 unsupported_task")
    func nonJSONTask() async {
        let api = TestSupport.makeAPIClient()
        let efCode = await serverCode {
            let _: EmptyResponse = try await api.request(PlainEndpoint(name: "f", transport: .edgeFunction))
        }
        #expect(efCode == "unsupported_task")

        let rpcCode = await serverCode {
            let _: EmptyResponse = try await api.request(
                PlainEndpoint(name: "f", transport: .rpc, task: .query([]))
            )
        }
        #expect(rpcCode == "unsupported_task")
    }

    @Test("미지의 transport — unsupported_transport (개방형 struct 의 안전망)")
    func unknownTransport() async {
        let api = TestSupport.makeAPIClient()
        let code = await serverCode {
            let _: EmptyResponse = try await api.request(
                PlainEndpoint(name: "q", transport: .init(rawValue: "graphQL"))
            )
        }
        #expect(code == "unsupported_transport")
    }

    @Test(".realtime 을 request 로 호출 — invalid_entry_point")
    func realtimeViaRequest() async {
        let api = TestSupport.makeAPIClient()
        let code = await serverCode {
            let _: EmptyResponse = try await api.request(PlainEndpoint(name: "w", transport: .realtime))
        }
        #expect(code == "invalid_entry_point")
    }

    @Test("비-.realtime 을 stream 으로 호출 — invalid_entry_point")
    func nonRealtimeViaStream() async {
        let api = TestSupport.makeAPIClient()
        let code = await serverCode {
            let _: AsyncThrowingStream<Int, Error> = try await api.stream(
                PlainEndpoint(name: "t", transport: .database)
            )
        }
        #expect(code == "invalid_entry_point")
    }

    @Test(".realtime — RealtimeEndpoint 미준수면 invalid_realtime_endpoint")
    func realtimeMismatch() async {
        let api = TestSupport.makeAPIClient()
        let code = await serverCode {
            let _: AsyncThrowingStream<Int, Error> = try await api.stream(
                PlainEndpoint(name: "w", transport: .realtime)
            )
        }
        #expect(code == "invalid_realtime_endpoint")
    }

    @Test("stream — RealtimeEndpoint 의 executeStream 으로 위임")
    func streamDelegatesToEndpoint() async throws {
        let api = TestSupport.makeAPIClient()

        let stream: AsyncThrowingStream<Int, Error> = try await api.stream(
            StubRealtimeEndpoint(events: [1, 2])
        )

        var received: [Int] = []
        for try await event in stream {
            received.append(event)
        }
        #expect(received == [1, 2])
    }
}
