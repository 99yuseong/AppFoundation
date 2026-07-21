//
//  AuthService.swift
//  AppFoundation / AuthKit
//

import Foundation

/// 인증 진입점: 소셜 로그인/로그아웃/재인증과 REST 호출용 access token 공급.
/// 표준 구현은 `DefaultAuthService`(backend + providers 조립),
/// 테스트/프리뷰는 `MockAuthService` 를 쓴다.
public protocol AuthService: Sendable {

    /// 현재 로그인된 auth identity(로그인 상태일 때). 별도의 "이전 로그인 복원"
    /// 호출은 없다: 앱 실행 시 복원은 `authEvents` 의 `.initialSessionLoaded`
    /// 이벤트로 드러나고, 이 접근자가 그 상태를 반영한다.
    var currentIdentity: AuthIdentity? { get async }

    /// auth 상태 변화 스트림(`AuthEvent` 참조). 각 이벤트에는 그 이후 유효한
    /// identity 가 실린다(로그아웃/삭제 시 nil). 앱은 이걸 관찰해 세션이 바뀌거나
    /// 무효화되는 상황에 반응한다.
    var authEvents: AsyncStream<(event: AuthEvent, identity: AuthIdentity?)> { get }

    /// 주어진 provider 로 로그인하고, 확립된 identity 와 로그인에 쓰인 credential 을
    /// 돌려준다. `presenter` 는 provider SDK 가 UI 를 present 할 뷰컨트롤러를
    /// 공급한다(Google 계정 피커, Apple 시트 anchor).
    func signIn(with provider: SocialProvider, presenter: AuthPresenter?) async throws -> SignInResult

    /// 회원탈퇴용 재인증. provider 로그인 UI 를 다시 띄워 fresh credential 을 확보해
    /// 돌려준다. 세션은 건드리지 않는다. 탈퇴 EF 본문용 값만 필요하면
    /// `WithdrawalCredential(folding:)` 으로 접는다.
    func reauthenticate(provider: SocialProvider, presenter: AuthPresenter?) async throws -> AuthCredential

    /// 로그아웃한다. `.global` 은 모든 기기의 세션을 종료한다.
    func signOut(scope: SignOutScope) async throws

    /// provider 로컬 + 백엔드 세션을 best-effort 로 정리한다(탈퇴 성공 후 호출).
    /// 세션은 서버에서 이미 삭제됐을 수 있어 백엔드 signOut 실패는 삼킨다.
    func endSession() async

    /// REST 요청 인증용(`Bearer <token>`) 신선한 access token.
    var accessToken: String? { get async }

    /// 앱이 받은 OAuth 콜백 URL 을 처리한다(SwiftUI `.onOpenURL`).
    /// provider SDK 를 모듈 안에 가둬 앱이 직접 import 하지 않게 한다.
    /// provider 가 URL 을 소비하면 true.
    @MainActor
    func handle(_ url: URL) -> Bool
}

extension AuthService {

    /// presenter 없이 로그인 — 프리뷰/테스트용.
    public func signIn(with provider: SocialProvider) async throws -> SignInResult {
        try await signIn(with: provider, presenter: nil)
    }

    /// presenter 없이 재인증 — 프리뷰/테스트용.
    public func reauthenticate(provider: SocialProvider) async throws -> AuthCredential {
        try await reauthenticate(provider: provider, presenter: nil)
    }

    /// 이 기기의 세션만 종료.
    public func signOut() async throws {
        try await signOut(scope: .local)
    }
}
