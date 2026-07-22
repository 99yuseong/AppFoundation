//
//  APIEnvelopeTests.swift
//  AppFoundation / APIKitTests
//

import Foundation
import Testing
@testable import APIKit

@Suite("APIEnvelope")
struct APIEnvelopeTests {

    struct Payload: Decodable, Equatable {
        let value: Int
    }

    @Test("성공 envelope — data 디코드")
    func success() throws {
        let json = #"{"ok":true,"data":{"value":7}}"#
        let envelope = try JSONDecoder().decode(APIEnvelope<Payload>.self, from: Data(json.utf8))
        #expect(envelope.ok)
        #expect(envelope.data == Payload(value: 7))
    }

    @Test("실패 envelope — error code/message 디코드")
    func failure() throws {
        let json = #"{"ok":false,"error":{"code":"c","message":"m"}}"#
        let envelope = try JSONDecoder().decode(APIErrorEnvelope.self, from: Data(json.utf8))
        #expect(!envelope.ok)
        #expect(envelope.error.code == "c")
        #expect(envelope.error.message == "m")
    }
}
