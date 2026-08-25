//
//  StorageClient.swift
//  AppFoundation / APIKit
//
//  오브젝트 저장소 실행의 중립 계약. Supabase Storage ↔ Cloudflare R2 교체가
//  조립 한 줄이 되도록, 호출부(endpoint·표시 계층)는 이 계약만 본다.
//  APIClient 의 verb 금지 원칙과 같은 이유로 연산을 최소로 유지한다 —
//  실사용이 증명된 upload/url 둘뿐이며, delete/list 는 필요가 생길 때 추가한다.
//

import Foundation

/// 오브젝트 저장소 실행 계약. 구현: SupabaseStorageClient(APIKitSupabase),
/// R2StorageClient(APIKitR2), MockStorageClient(테스트).
public protocol StorageClient: Sendable {

    /// `path` 에 바이트를 올린다 — 같은 경로는 덮어쓴다(upsert). 재업로드가 잔여
    /// 오브젝트를 남기지 않아 별도 정리가 불필요하다.
    ///
    /// 반환값은 서버가 확정한 오브젝트 경로다. 호출부가 넘긴 `path` 와 보통 같지만
    /// 서버가 정규화할 수 있으니 **이 반환값을 DB 저장 정본으로 쓴다** — URL 이
    /// 아니라 path 를 저장해야 저장소 교체 시 데이터가 살아남는다.
    @discardableResult
    func upload(
        _ data: Data,
        to bucket: any StorageBucket.Type,
        path: String,
        contentType: String
    ) async throws -> String

    /// `path` 오브젝트를 열 수 있는 URL 을 돌려준다. public 버킷은 고정 공개 URL,
    /// private 버킷은 `bucket.signedURLExpiry` 시한부 서명 URL — 분기는 구현이
    /// 흡수하므로 호출부는 버킷 공개 여부를 몰라도 된다.
    ///
    /// 서명 URL 은 발급마다 달라지는 휘발성 파생물이다 — 저장·캐시 키로 쓰지 말고
    /// 전송에만 쓴다 (캐시 키는 path).
    func url(
        for bucket: any StorageBucket.Type,
        path: String
    ) async throws -> URL
}
