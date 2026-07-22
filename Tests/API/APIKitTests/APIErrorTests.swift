//
//  APIErrorTests.swift
//  AppFoundation / APIKitTests
//

import Foundation
import Testing
@testable import APIKit

@Suite("APIError")
struct APIErrorTests {

    @Test("공통 code 매핑 — invalid_request/unauthorized 승격, 나머지는 server 통과")
    func codeMapping() {
        #expect(APIError(code: "invalid_request", message: "m") == .invalidRequest(message: "m"))
        #expect(APIError(code: "unauthorized", message: "m") == .unauthorized(message: "m"))
        #expect(APIError(code: "account_banned", message: "m") == .server(code: "account_banned", message: "m"))
    }

    @Test("envelope 본문 매핑 — {ok:false,error} 형식만, 규약 밖이면 nil")
    func envelopeMapping() {
        let envelope = #"{"ok":false,"error":{"code":"unauthorized","message":"만료"}}"#
        #expect(APIError(envelopeData: Data(envelope.utf8)) == .unauthorized(message: "만료"))

        let outside = #"{"message":"gateway timeout"}"#
        #expect(APIError(envelopeData: Data(outside.utf8)) == nil)
    }
}
