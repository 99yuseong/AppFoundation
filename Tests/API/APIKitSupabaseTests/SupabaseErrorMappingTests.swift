//
//  SupabaseErrorMappingTests.swift
//  AppFoundation / APIKitSupabaseTests
//
//  서버 (code, message) 매핑 — 훅 우선, 중립 APIError 폴백.
//

import Testing
import APIKit
@testable import APIKitSupabase

@Suite("SupabaseAPIClient 에러 매핑")
struct SupabaseErrorMappingTests {

    enum DomainError: Error, Equatable {
        case accountBanned
    }

    @Test("훅 우선 — 앱 도메인 에러로 승격")
    func hookFirst() {
        let api = TestSupport.makeAPIClient { code, _ in
            code == "account_banned" ? DomainError.accountBanned : nil
        }
        #expect(api.mapError(code: "account_banned", message: "m") as? DomainError == .accountBanned)
    }

    @Test("훅 없음 — 중립 APIError 폴백 (공통 코드 승격 포함)")
    func neutralFallback() {
        let api = TestSupport.makeAPIClient()
        #expect(api.mapError(code: "unauthorized", message: "m") as? APIError == .unauthorized(message: "m"))
        #expect(api.mapError(code: "DR004", message: "banned") as? APIError == .server(code: "DR004", message: "banned"))
    }

    @Test("훅이 nil 을 반환한 코드 — 중립 폴백으로 통과")
    func hookPassthrough() {
        let api = TestSupport.makeAPIClient { code, _ in
            code == "account_banned" ? DomainError.accountBanned : nil
        }
        #expect(api.mapError(code: "other", message: "m") as? APIError == .server(code: "other", message: "m"))
    }
}
