//
//  StorageEndpoint.swift
//  AppFoundation / APIKitSupabase
//
//  Storage endpoint — DatabaseEndpoint 와 대칭 구조. 엔드포인트가 자기 버킷/경로를
//  알고, executeStorage 안에서 SDK 를 직접 실행한다. APIClient 는 전송 방식
//  (.storage)만 보고 이 메서드로 넘긴다.
//
//  저장소 교체(Supabase ↔ R2)가 필요한 신규 코드는 이 경로가 아니라
//  `StorageClient`(중립 계약)를 조립에서 Repository 로 직주입해 쓴다 — endpoint
//  흐름은 storage 를 모른다(소비 경로 일원화). 이 경로는 SDK 전 기능 접근용이다.
//

import Foundation
import APIKit
import Supabase

public protocol StorageEndpoint: Endpoint {
    func executeStorage<Response: Decodable>(
        context: StorageContext,
        response: Response.Type
    ) async throws -> Response
}

public struct StorageContext: Sendable {

    /// 공유 SupabaseClient. SDK 전 기능 접근용.
    public let client: SupabaseClient

    public init(client: SupabaseClient) {
        self.client = client
    }
}
