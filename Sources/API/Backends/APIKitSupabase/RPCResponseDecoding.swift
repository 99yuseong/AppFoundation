//
//  RPCResponseDecoding.swift
//  AppFoundation / APIKitSupabase
//
//  RPC 응답 디코딩 규칙 — SupabaseClient 없이 단위 테스트 가능하도록 순수 함수로 분리.
//

import Foundation
import APIKit

enum RPCResponseDecoding {

    /// `returns table (...)` RPC 는 PostgREST 가 결과를 row 배열([{...}])로 내려주므로,
    /// 먼저 [Response] 로 디코딩해 첫 원소를 취하고, 스칼라/객체 반환 RPC 는 단일
    /// Response 로 폴백한다. 배열이 비어 있으면 계약 위반으로 드러낸다.
    static func decode<Response: Decodable>(
        _ data: Data,
        name: String,
        using decoder: JSONDecoder = JSONDecoder()
    ) throws -> Response {
        if let rows = try? decoder.decode([Response].self, from: data) {
            guard let first = rows.first else {
                throw APIError.server(code: "empty_rpc_result", message: "\(name) 이 빈 결과 반환")
            }
            return first
        }

        return try decoder.decode(Response.self, from: data)
    }
}
