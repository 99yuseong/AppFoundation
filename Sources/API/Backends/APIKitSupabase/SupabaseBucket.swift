//
//  SupabaseBucket.swift
//  AppFoundation / APIKitSupabase
//
//  Storage 로 직접 조작하는 버킷을 타입으로 표현한다. SupabaseTable 과 대칭 —
//  버킷명을 문자열로 호출부에 흩뿌리면 서버가 버킷을 바꿀 때 산재한 오타를 잡기 어렵다.
//  이름을 각 버킷 타입 한 곳에 모아, 서버 storage.buckets 정의와 1:1로 맞춘다.
//
//  구조: 각 버킷은 이 프로토콜을 준수하는 별도 타입(앱 소유, 별도 파일)이다. 버킷명·공개
//  여부와 "이 버킷에 올린다"(upload)를 자기가 소유하므로, 새 버킷은 준수 타입 하나를
//  추가하는 것으로 끝난다. Storage SDK 호출은 이 경계 안에 갇히고, endpoint 는 버킷
//  선택만 한다. 표시/다운로드는 이 경계 밖(표시 계층) — public 버킷은 getPublicURL,
//  private 버킷은 소유자 세션의 createSignedURL 로 연다(`isPublic` 이 분기 기준).
//

import Foundation
import Supabase

/// Storage 로 직접 조작하는 버킷. 준수 타입이 버킷명·공개 여부와 업로드 동작을 소유한다.
/// 준수 타입 자체는 인스턴스가 필요 없는 순수 네임스페이스라 보통 case 없는 enum 으로 둔다.
public protocol SupabaseBucket {

    /// Storage `.from(_:)` 에 실리는 실제 버킷명. 이 버킷 문자열의 유일한 출처.
    static var bucketName: String { get }

    /// 공개 버킷 여부. public 이면 공개 URL 로 열리고, false(private)면 세션 서명 URL 이
    /// 있어야 접근할 수 있다(storage.objects RLS). 표시/다운로드 계층이 이 값으로 분기한다.
    static var isPublic: Bool { get }
}

extension SupabaseBucket {

    /// `path` 에 바이트를 올린다(같은 경로는 덮어쓴다, upsert). 세션 JWT 는 공유
    /// SupabaseClient 가 자동으로 실어 storage.objects RLS(본인 폴더 쓰기)를 통과한다.
    /// 재업로드가 잔여 오브젝트를 남기지 않아 별도 정리가 불필요하다.
    ///
    /// 반환값은 서버가 확정한 오브젝트 경로(`FileUploadResponse.path`)다 — 호출부가 넘긴
    /// `path` 와 보통 같지만, 서버가 정규화할 수 있으니 이 반환값을 DB 저장 정본으로 쓴다.
    @discardableResult
    public static func upload(
        _ data: Data,
        to path: String,
        contentType: String,
        using client: SupabaseClient
    ) async throws -> String {
        try await client.storage
            .from(bucketName)
            .upload(path, data: data, options: FileOptions(contentType: contentType, upsert: true))
            .path
    }
}
