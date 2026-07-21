//
//  AuthBackend.swift
//  AppFoundation / AuthKit
//

/// 인증 백엔드: provider credential 을 세션과 교환하고 세션 수명주기를 소유한다.
///
/// 현재 구현은 `AuthKitSupabase.SupabaseAuthBackend` 하나. Firebase Auth 등으로
/// 확장할 때 이 프로토콜의 구현 타겟만 추가하면 provider(AuthKit·AuthKitGoogle·
/// AuthKitKakao)와 오케스트레이터(`DefaultAuthService`)는 그대로 재사용된다.
public protocol AuthBackend: Sendable {

    /// 현재 로그인된 identity(로그인 상태일 때). SDK 의 라이브 세션을 읽는다.
    var currentIdentity: AuthIdentity? { get async }

    /// auth 상태 변화 스트림. 백엔드가 구동하므로 토큰 갱신·만료·서버측 revoke 까지
    /// 잡아낸다.
    var events: AsyncStream<(event: AuthEvent, identity: AuthIdentity?)> { get }

    /// provider credential 을 백엔드 세션과 교환한다.
    func exchange(_ credential: AuthCredential) async throws -> AuthIdentity

    /// 백엔드 세션을 종료한다.
    func signOut(scope: SignOutScope) async throws

    /// REST 요청 인증용(`Bearer <token>`) 신선한 access token.
    var accessToken: String? { get async }
}
