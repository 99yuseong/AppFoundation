//
//  WithdrawalCredential.swift
//  AppFoundation / AuthKit
//
//  회원탈퇴 재인증으로 확보한 provider별 fresh credential. account-withdraw 류
//  Edge Function 본문에 실려 서버가 소셜 토큰 revoke 를 인라인 수행한다.
//  `AuthCredential`(AuthenticationServices 의존 값 포함)을 서버 경계 밖으로 새지
//  않게 하는 순수 값 경계 타입 — 서버가 필요로 하는 문자열만 담는다.
//

/// 회원탈퇴 시 서버 revoke 에 쓰일 provider별 fresh credential.
public enum WithdrawalCredential: Equatable, Sendable {

    /// Apple: 재인증으로 얻은 1회성 authorization code(서버가 .p8 로 `/auth/revoke` 호출).
    case apple(authorizationCode: String)

    /// Google: OAuth access token(서버가 Google revoke 엔드포인트로 전달).
    case google(token: String)

    /// Kakao: identity token. 서버는 admin key 로 unlink 하므로 보통 사용자 식별
    /// (`sub` claim)에만 쓴다 — 서버가 auth identities 에서 직접 찾으면 불필요.
    case kakao(idToken: String)

    /// 앱 정의 provider: 재인증 credential 의 parameters 를 그대로 나른다.
    /// 서버 revoke 에 무엇이 필요한지는 앱 서버 계약이 정한다.
    case custom(provider: SocialProvider, parameters: [String: String])

    /// 재인증으로 얻은 `AuthCredential` 을 접는다. Apple 이 authorization code 를
    /// 생략하면(재인증인데도 없으면) revoke 를 못 하므로 `missingCredential` 로 던진다.
    public init(folding credential: AuthCredential) throws {
        switch credential {
        case let .apple(_, _, authorizationCode, _, _):
            guard let authorizationCode else { throw AuthKitError.missingCredential }
            self = .apple(authorizationCode: authorizationCode)

        case let .google(_, accessToken):
            self = .google(token: accessToken)

        case let .kakao(idToken, _):
            self = .kakao(idToken: idToken)

        case let .custom(provider, parameters):
            self = .custom(provider: provider, parameters: parameters)
        }
    }
}
