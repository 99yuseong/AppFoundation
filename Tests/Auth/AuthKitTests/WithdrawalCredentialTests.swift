//
//  WithdrawalCredentialTests.swift
//  AppFoundation / AuthKitTests
//

import Testing
@testable import AuthKit

@Suite("WithdrawalCredential folding")
struct WithdrawalCredentialTests {

    @Test("apple — authorizationCode 를 접는다")
    func foldApple() throws {
        let credential = AuthCredential.apple(
            idToken: "t", rawNonce: "n", authorizationCode: "code-123", fullName: nil, email: nil
        )
        #expect(try WithdrawalCredential(folding: credential) == .apple(authorizationCode: "code-123"))
    }

    @Test("apple — authorizationCode 누락 시 missingCredential throw (revoke 불가)")
    func foldAppleMissingCode() {
        let credential = AuthCredential.apple(
            idToken: "t", rawNonce: "n", authorizationCode: nil, fullName: nil, email: nil
        )
        #expect(throws: AuthKitError.self) {
            _ = try WithdrawalCredential(folding: credential)
        }
    }

    @Test("google — accessToken 을 접는다 (revoke 는 access token 만 받는다)")
    func foldGoogle() throws {
        let credential = AuthCredential.google(idToken: "id", accessToken: "access-456")
        #expect(try WithdrawalCredential(folding: credential) == .google(token: "access-456"))
    }

    @Test("kakao — idToken 을 접는다")
    func foldKakao() throws {
        let credential = AuthCredential.kakao(idToken: "kakao-id-token", rawNonce: "n")
        #expect(try WithdrawalCredential(folding: credential) == .kakao(idToken: "kakao-id-token"))
    }
}
