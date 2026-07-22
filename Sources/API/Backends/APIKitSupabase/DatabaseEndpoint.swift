//
//  DatabaseEndpoint.swift
//  AppFoundation / APIKitSupabase
//
//  Database endpoint — 엔드포인트가 context 의 Supabase SDK 로 테이블 조작을 직접
//  실행한다. EF 호출 수 제한(비용)을 피하는 클라 조합 경로라, 과도한 추상화 없이
//  SDK 전 기능을 쓸 수 있도록 SupabaseClient 를 그대로 노출한다 (의도된 설계).
//  자체 서버로 확장하면 executeDatabase 안의 로직이 서버로 이동하고, 엔드포인트는
//  선언(transport 등)만 바뀐다 — Repository 는 APIClient 만 보므로 무변경.
//

import APIKit
import Supabase

public protocol DatabaseEndpoint: Endpoint {
    func executeDatabase<Response: Decodable>(
        context: DatabaseContext,
        response: Response.Type
    ) async throws -> Response
}

public struct DatabaseContext: Sendable {

    public let client: SupabaseClient

    /// 본인 행 특정용 서비스 유저 id 제공자 (RLS + 명시적 id 필터 병용).
    public let userIDProvider: any CurrentUserIDProviding

    public init(client: SupabaseClient, userIDProvider: any CurrentUserIDProviding) {
        self.client = client
        self.userIDProvider = userIDProvider
    }
}
