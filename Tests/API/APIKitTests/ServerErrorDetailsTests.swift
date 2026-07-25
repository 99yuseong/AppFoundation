//
//  ServerErrorDetailsTests.swift
//  AppFoundation / APIKitTests
//
//  실패 본문의 부가 필드를 앱까지 전달하는 경로. code/message 두 문자열로 표현할 수
//  없는 값(재시도 대상 id 등)이 매핑 경계에서 버려지지 않는지 고정한다.
//

import Foundation
import Testing
@testable import APIKit

@Suite("ServerErrorDetails")
struct ServerErrorDetailsTests {

    /// 앱이 자기 계약으로 선언하는 부가 필드 — kit 은 이 스키마를 모른다.
    private struct BusyHint: Decodable, Equatable {
        let incomingNegotiationID: String
        let peerID: String

        enum CodingKeys: String, CodingKey {
            case incomingNegotiationID = "incoming_negotiation_id"
            case peerID = "peer_id"
        }
    }

    private func details(_ json: String) -> ServerErrorDetails {
        ServerErrorDetails(rawBody: Data(json.utf8))
    }

    @Test("envelope 의 error 객체를 앱 타입으로 디코딩")
    func decodesErrorObject() {
        let body = """
        {"ok":false,"error":{"code":"callee_busy","message":"협상 중",
         "incoming_negotiation_id":"neg-1","peer_id":"user-2"}}
        """
        #expect(
            details(body).decode(BusyHint.self)
                == BusyHint(incomingNegotiationID: "neg-1", peerID: "user-2")
        )
    }

    @Test("부가 필드 없으면 nil — 없는 것이 정상 경로다")
    func missingFieldsYieldNil() {
        let body = #"{"ok":false,"error":{"code":"callee_busy","message":"협상 중"}}"#
        #expect(details(body).decode(BusyHint.self) == nil)
    }

    @Test("string(forKey:) — error 객체의 문자열 필드 지름길")
    func stringLookup() {
        let body = #"{"ok":false,"error":{"code":"c","message":"m","incoming_negotiation_id":"neg-9"}}"#
        #expect(details(body).string(forKey: "incoming_negotiation_id") == "neg-9")
        #expect(details(body).string(forKey: "absent") == nil)
    }

    @Test("숫자·불리언은 문자열로 바꿔 주지 않는다 — 조용한 타입 혼동 방지")
    func nonStringNotCoerced() {
        let body = #"{"ok":false,"error":{"code":"c","message":"m","retry_after":30,"fatal":true}}"#
        #expect(details(body).string(forKey: "retry_after") == nil)
        #expect(details(body).string(forKey: "fatal") == nil)
    }

    @Test("envelope 규약 밖 본문은 전체를 대상으로 폴백")
    func nonEnvelopeFallsBackToWholeBody() {
        let body = #"{"incoming_negotiation_id":"neg-3"}"#
        #expect(details(body).string(forKey: "incoming_negotiation_id") == "neg-3")
    }

    @Test("JSON 이 아니면 nil — 게이트웨이 평문 응답 등")
    func nonJSONYieldsNil() {
        #expect(details("gateway timeout").string(forKey: "any") == nil)
        #expect(details("gateway timeout").decode(BusyHint.self) == nil)
    }
}
