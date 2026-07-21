//
//  SupabaseAuthMappingTests.swift
//  AppFoundation / AuthKitSupabaseTests
//

import Supabase
import Testing
@testable import AuthKit
@testable import AuthKitSupabase

@Suite("SupabaseAuthMapping")
struct SupabaseAuthMappingTests {

    @Test("AuthChangeEvent → AuthEvent 매핑")
    func eventMapping() {
        #expect(SupabaseAuthMapping.authEvent(from: .initialSession) == .initialSessionLoaded)
        #expect(SupabaseAuthMapping.authEvent(from: .signedIn) == .signedIn)
        #expect(SupabaseAuthMapping.authEvent(from: .signedOut) == .signedOut)
        #expect(SupabaseAuthMapping.authEvent(from: .tokenRefreshed) == .tokenRefreshed)
        #expect(SupabaseAuthMapping.authEvent(from: .userDeleted) == .userDeleted)
    }

    @Test("다루지 않는 이벤트는 nil 드롭")
    func eventMappingDrops() {
        #expect(SupabaseAuthMapping.authEvent(from: .passwordRecovery) == nil)
        #expect(SupabaseAuthMapping.authEvent(from: .userUpdated) == nil)
        #expect(SupabaseAuthMapping.authEvent(from: .mfaChallengeVerified) == nil)
    }

    @Test("appMetadata provider 매핑 — apple/google/kakao")
    func providerMapping() {
        #expect(SupabaseAuthMapping.provider(fromAppMetadata: ["provider": .string("apple")]) == .apple)
        #expect(SupabaseAuthMapping.provider(fromAppMetadata: ["provider": .string("google")]) == .google)
        #expect(SupabaseAuthMapping.provider(fromAppMetadata: ["provider": .string("kakao")]) == .kakao)
    }

    @Test("appMetadata provider 매핑 — 임의 문자열도 개방형 provider 로 매핑")
    func providerMappingOpen() {
        // SocialProvider 는 열린 struct — kit 이 모르는 문자열도 그대로 식별자가 된다.
        #expect(
            SupabaseAuthMapping.provider(fromAppMetadata: ["provider": .string("naver")])
                == SocialProvider(rawValue: "naver")
        )
    }

    @Test("appMetadata provider 매핑 — 누락/비문자열은 nil")
    func providerMappingMissing() {
        #expect(SupabaseAuthMapping.provider(fromAppMetadata: [:]) == nil)
        #expect(SupabaseAuthMapping.provider(fromAppMetadata: ["provider": .integer(1)]) == nil)
    }
}
