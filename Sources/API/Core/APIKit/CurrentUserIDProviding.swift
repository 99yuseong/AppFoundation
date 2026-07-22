//
//  CurrentUserIDProviding.swift
//  AppFoundation / APIKit
//
//  본인 행 특정용 서비스 유저 id 제공자. DB 직접 조작(PATCH 등)은 RLS 와 명시적 id
//  필터를 함께 쓰므로, 백엔드 실행 컨텍스트가 이 프로토콜로 현재 유저 id 를 얻는다.
//
//  구현은 백엔드/앱 소유 — 인증 세션 uid 를 그대로 쓰는 앱은 백엔드 기본 구현
//  (APIKitSupabase 의 `SupabaseSessionUserIDProvider`)을, 서비스 유저 id 가 별도인
//  앱은 자체 구현(예: 본인 행 조회)을 주입한다.
//

public protocol CurrentUserIDProviding: Sendable {
    func currentUserID() async throws -> String
}
