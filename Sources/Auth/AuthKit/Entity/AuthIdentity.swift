//
//  AuthIdentity.swift
//  AppFoundation / AuthKit
//

/// 로그인된 auth identity 스냅샷 — 라이브 세션이 아니라 *누가* 로그인했는지.
///
/// 설계 원칙: **세션은 값 객체가 아니다**. 라이브 세션(access/refresh 토큰, 만료,
/// 자동 갱신)은 `AuthService` 와 하부 SDK 가 소유하며, 매번 신선한 토큰을 돌려주는
/// async 접근자(`AuthService.accessToken`)로 접근한다. 세션을 값에 복사하면 토큰이
/// 만료되는 순간 낡아버리는 죽은 스냅샷을 잡게 되므로, 이 타입은 의도적으로 토큰도
/// 만료도 담지 않는다.
///
/// 세션 무효화(갱신, 만료, 서버측 revoke/제재, 삭제)는 이 값을 diff 하지 말고
/// `AuthService.authEvents` 로 관찰한다.
public struct AuthIdentity: Sendable, Equatable {

    public let uid: String
    public let provider: SocialProvider?
    /// 백엔드 세션에 실려 온 이메일(프로필 생성 참고용). 표시 데이터의 원천은
    /// 앱의 User 도메인이다.
    public let email: String?

    public init(uid: String, provider: SocialProvider? = nil, email: String? = nil) {
        self.uid = uid
        self.provider = provider
        self.email = email
    }
}
