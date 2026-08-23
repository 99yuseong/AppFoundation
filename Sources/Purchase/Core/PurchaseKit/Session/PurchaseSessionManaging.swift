//
//  PurchaseSessionManaging.swift
//  AppFoundation / PurchaseKit
//
//  결제 백엔드 계정 identity 수명주기 계약. 서버가 결제 백엔드의 app_user_id 로 구매자를
//  찾아 지급하는 구조에서는 서비스 유저 id 로 signIn 이 안 걸린 결제가 익명으로 들어가
//  지급이 무시된다 — identity 가 지급의 전제다. 계정 흐름(로그인·복원·로그아웃·탈퇴)에
//  이 계약을 배선하고, 구매 직전엔 `ensureSignedIn` 으로 self-heal 한다.
//

public protocol PurchaseSessionManaging: Sendable {

    /// 로그인/세션 복원 시 — configure(1회) 후 서비스 유저 id 로 signIn. 멱등이며
    /// 실패해도 던지지 않는다(계정 흐름을 막지 않는다 — 구매 전 `ensureSignedIn` 이 재시도).
    /// `userID` 는 서버가 내려준 **원문 그대로** 전달한다.
    func login(userID: String) async

    /// 로그아웃/탈퇴 시 identity 를 익명으로 되돌린다. 실패해도 던지지 않는다.
    func logout() async

    /// identity 가 필요 없는 호출(상품 조회) 전 configure 를 보장한다.
    func ensureConfigured() async

    /// 구매 직전 서명 보장. 미로그인이면 유저 id 를 직접 조회해 self-heal 하고,
    /// 그래도 identity 를 못 세우면 `PurchaseSessionError.identityUnavailable`.
    func ensureSignedIn() async throws
}
