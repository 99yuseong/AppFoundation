//
//  StorageBucket.swift
//  AppFoundation / APIKit
//
//  오브젝트 버킷의 중립 디스크립터 — 버킷명·공개 여부·서명 URL 만료 정책의 단일
//  진실 소스. 어느 저장소(Supabase Storage/R2)에 있는지는 모른다 — 실행은
//  StorageClient 구현이 담당한다.
//
//  준수 타입은 인스턴스가 필요 없는 순수 네임스페이스라 보통 case 없는 enum 으로
//  둔다 (SupabaseBucket 선례 — 그 프로토콜이 이 계약을 상속한다).
//

import Foundation

/// 오브젝트 버킷 선언. 준수 타입이 버킷명·공개 여부·만료 정책을 소유한다.
public protocol StorageBucket {

    /// 실제 버킷명. 이 문자열의 유일한 출처 — 호출부에 흩뿌리지 않는다.
    static var bucketName: String { get }

    /// 공개 버킷 여부. true 면 고정 공개 URL 로 열리고, false 면 시한부 서명 URL 이
    /// 있어야 접근할 수 있다. `StorageClient.url(for:path:)` 가 이 값으로 분기한다.
    static var isPublic: Bool { get }

    /// private 버킷 서명 URL 의 만료(초). 만료 정책은 리소스(버킷)의 성질이므로
    /// 호출부가 아니라 버킷이 소유한다. 기본 1시간.
    static var signedURLExpiry: TimeInterval { get }
}

extension StorageBucket {

    public static var signedURLExpiry: TimeInterval { 3600 }
}
