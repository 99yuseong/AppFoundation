//
//  NonceGeneratorTests.swift
//  AppFoundation / AuthKitTests
//

import Testing
@testable import AuthKit

@Suite("NonceGenerator")
struct NonceGeneratorTests {

    @Test("기본 길이 32자")
    func defaultLength() {
        #expect(NonceGenerator.random().count == 32)
    }

    @Test("지정 길이 준수")
    func customLength() {
        #expect(NonceGenerator.random(length: 64).count == 64)
        #expect(NonceGenerator.random(length: 1).count == 1)
    }

    @Test("charset 준수 — URL-safe 문자만")
    func charsetCompliance() {
        let allowed = Set("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = NonceGenerator.random(length: 256)
        #expect(nonce.allSatisfy { allowed.contains($0) })
    }

    @Test("연속 호출 유일성")
    func uniqueness() {
        let nonces = (0..<10).map { _ in NonceGenerator.random() }
        #expect(Set(nonces).count == nonces.count)
    }

    @Test("sha256 known vector")
    func sha256KnownVector() {
        // SHA256("abc") 표준 테스트 벡터
        #expect(
            NonceGenerator.sha256("abc")
            == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
    }

    @Test("sha256 hex 소문자 64자")
    func sha256Format() {
        let hash = NonceGenerator.sha256(NonceGenerator.random())
        #expect(hash.count == 64)
        #expect(hash.allSatisfy { "0123456789abcdef".contains($0) })
    }
}
