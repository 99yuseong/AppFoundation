//
//  NoopPurchaseSessionManager.swift
//  AppFoundation / PurchaseKit
//

/// 프리뷰/테스트 기본값 — 스토어 SDK 를 건드리지 않는 no-op.
public struct NoopPurchaseSessionManager: PurchaseSessionManaging {
    public init() {}
    public func login(userID: String) async {}
    public func logout() async {}
    public func ensureConfigured() async {}
    public func ensureSignedIn() async throws {}
}
