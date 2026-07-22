//
//  SupabaseSessionUserIDProvider.swift
//  AppFoundation / APIKitSupabase
//
//  인증 세션의 uid 를 그대로 서비스 유저 id 로 쓰는 기본 구현. auth.users.id 와
//  서비스 테이블 pk 가 같은 앱이면 이걸로 충분하다. 서비스 유저 id 가 별도인 앱
//  (예: 본인 행 조회로 id 를 얻는 구조)은 자체 `CurrentUserIDProviding` 구현을
//  `SupabaseAPIClient` 에 주입한다.
//

import APIKit
import Supabase

public struct SupabaseSessionUserIDProvider: CurrentUserIDProviding {

    private let client: SupabaseClient

    public init(client: SupabaseClient) {
        self.client = client
    }

    /// 현재 세션의 uid. Postgres uuid 텍스트 표기와 맞추기 위해 소문자로 반환한다.
    public func currentUserID() async throws -> String {
        try await client.auth.session.user.id.uuidString.lowercased()
    }
}
