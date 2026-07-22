//
//  RPCResponseDecodingTests.swift
//  AppFoundation / APIKitSupabaseTests
//

import Foundation
import Testing
import APIKit
@testable import APIKitSupabase

@Suite("RPCResponseDecoding")
struct RPCResponseDecodingTests {

    struct Row: Decodable, Equatable {
        let value: Int
    }

    @Test("returns table — row 배열의 첫 원소")
    func arrayFirst() throws {
        let row: Row = try RPCResponseDecoding.decode(Data(#"[{"value":1},{"value":2}]"#.utf8), name: "f")
        #expect(row == Row(value: 1))
    }

    @Test("빈 배열 — 계약 위반(empty_rpc_result) 에러")
    func emptyArray() {
        #expect(throws: APIError.server(code: "empty_rpc_result", message: "f 이 빈 결과 반환")) {
            let _: Row = try RPCResponseDecoding.decode(Data("[]".utf8), name: "f")
        }
    }

    @Test("스칼라/객체 반환 — 단일 값 폴백")
    func scalarAndObjectFallback() throws {
        let value: Int = try RPCResponseDecoding.decode(Data("7".utf8), name: "f")
        #expect(value == 7)

        let row: Row = try RPCResponseDecoding.decode(Data(#"{"value":3}"#.utf8), name: "f")
        #expect(row == Row(value: 3))
    }

    @Test("계약 불일치 — 디코딩 에러 그대로 드러남")
    func mismatch() {
        #expect(throws: (any Error).self) {
            let _: Row = try RPCResponseDecoding.decode(Data(#"{"other":true}"#.utf8), name: "f")
        }
    }
}
