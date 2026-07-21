//
//  AuthEvent.swift
//  AppFoundation / AuthKit
//

/// auth 상태 변화. `AuthService.authEvents` 로 관찰한다. 백엔드가 push 하며
/// (우리 signIn/signOut 호출만이 아니다) 토큰 갱신, 만료, 서버측 revoke(예: 제재)가
/// 모두 여기로 드러난다. 자동 로그인 구동과, 무효화된 세션을 밀어내는 데 쓴다.
public enum AuthEvent: String, Sendable {

    /// 로컬에 저장된 세션이 실행 시 복원됨.
    case initialSessionLoaded = "INITIAL_SESSION_LOADED"

    /// 로그인됨, 또는 세션이 재확립됨.
    case signedIn = "SIGNED_IN"

    /// 로그아웃됨, 또는 세션이 만료/revoke 됨.
    case signedOut = "SIGNED_OUT"

    /// access token 이 갱신됨.
    case tokenRefreshed = "TOKEN_REFRESHED"

    /// 사용자가 삭제됨.
    case userDeleted = "USER_DELETED"
}
