//
//  SupabaseAuthMapping.swift
//  AppFoundation / AuthKitSupabase
//
//  Supabase 타입 → AuthKit 타입 매핑. 순수 함수 — 단위 테스트 대상.
//

import AuthKit
import Foundation
import Supabase

enum SupabaseAuthMapping {

    /// Supabase `AuthChangeEvent` 를 `AuthEvent` 로 매핑한다. 우리가 다루지 않는
    /// 이벤트(비밀번호 복구, user-updated, MFA)는 nil 로 드롭한다.
    static func authEvent(from event: AuthChangeEvent) -> AuthEvent? {
        switch event {
        case .initialSession: .initialSessionLoaded
        case .signedIn: .signedIn
        case .signedOut: .signedOut
        case .tokenRefreshed: .tokenRefreshed
        case .userDeleted: .userDeleted
        case .passwordRecovery, .userUpdated, .mfaChallengeVerified: nil
        @unknown default: nil
        }
    }

    /// Supabase `Session` 을 `AuthIdentity` 로 매핑한다.
    static func identity(from session: Session, provider overrideProvider: SocialProvider? = nil) -> AuthIdentity {
        AuthIdentity(
            uid: session.user.id.uuidString,
            provider: overrideProvider ?? provider(fromAppMetadata: session.user.appMetadata),
            email: session.user.email
        )
    }

    static func provider(fromAppMetadata metadata: [String: AnyJSON]) -> SocialProvider? {
        guard case let .string(provider)? = metadata["provider"] else { return nil }
        return SocialProvider(rawValue: provider)
    }
}
