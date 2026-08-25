//
//  StorageEndpoint.swift
//  AppFoundation / APIKitSupabase
//
//  Storage endpoint — DatabaseEndpoint 와 대칭 구조. 엔드포인트가 자기 버킷/경로를
//  알고, executeStorage 안에서 저장소를 직접 실행한다. APIClient 는 전송 방식
//  (.storage)만 보고 이 메서드로 넘긴다.
//
//  실행은 context.storage(StorageClient 중립 계약) 경유를 권장한다 — 저장소 교체
//  (Supabase Storage ↔ R2)가 조립 주입만으로 끝난다. context.client 는 호환·SDK
//  전 기능 접근용으로 유지한다.
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

    /// 공유 SupabaseClient. SDK 전 기능 접근용 — 신규 코드는 `storage` 경유 권장.
    public let client: SupabaseClient

    /// 저장소 실행의 중립 계약. 조립에서 교체 주입하면 저장소 백엔드가 바뀐다.
    public let storage: any StorageClient

    /// - Parameter storage: 미지정 시 Supabase Storage 실행(SupabaseStorageClient).
    ///   기존 `init(client:)` 호출부는 그대로 컴파일된다.
    public init(client: SupabaseClient, storage: (any StorageClient)? = nil) {
        self.client = client
        self.storage = storage ?? SupabaseStorageClient(client: client)
    }
}
