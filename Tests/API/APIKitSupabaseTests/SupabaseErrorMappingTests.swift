//
//  SupabaseErrorMappingTests.swift
//  AppFoundation / APIKitSupabaseTests
//
//  서버 (code, message) 매핑 — 훅 우선, 중립 APIError 폴백.
//

import Foundation
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

    // MARK: - 부가 필드 전달

    enum HintError: Error, Equatable {
        case busy(negotiationID: String?)
    }

    @Test("훅이 실패 본문의 부가 필드를 받는다 — code/message 로는 못 싣는 값")
    func hookReceivesDetails() {
        let api = TestSupport.makeAPIClient { _, _, details in
            HintError.busy(negotiationID: details?.string(forKey: "incoming_negotiation_id"))
        }

        let body = #"{"ok":false,"error":{"code":"callee_busy","message":"m","incoming_negotiation_id":"neg-7"}}"#
        let mapped = api.mapError(
            code: "callee_busy",
            message: "m",
            details: ServerErrorDetails(rawBody: Data(body.utf8))
        )

        #expect(mapped as? HintError == .busy(negotiationID: "neg-7"))
    }

    @Test("details 없는 경로(RPC 등)에서는 nil 로 들어온다")
    func detailsAbsentForRPC() {
        let api = TestSupport.makeAPIClient { _, _, details in
            HintError.busy(negotiationID: details?.string(forKey: "incoming_negotiation_id"))
        }
        #expect(api.mapError(code: "callee_busy", message: "m") as? HintError == .busy(negotiationID: nil))
    }
}
