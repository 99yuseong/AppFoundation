//
//  SignInResult.swift
//  AppFoundation / AuthKit
//

/// 로그인 결과: 확립된 identity 와, 로그인에 쓰인 provider credential.
///
/// credential 을 함께 돌려주는 이유: 앱이 로그인 직후에만 얻을 수 있는 값을
/// 필요로 할 수 있다 — 예: Apple authorizationCode 를 서버로 보내 refresh token 을
/// 보관(서버 보관형 탈퇴 전략), fullName/email 로 최초 프로필 생성.
public struct SignInResult: Sendable {

    public let identity: AuthIdentity
    public let credential: AuthCredential

    public init(identity: AuthIdentity, credential: AuthCredential) {
        self.identity = identity
        self.credential = credential
    }
}
