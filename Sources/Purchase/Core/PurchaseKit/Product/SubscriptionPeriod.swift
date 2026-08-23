//
//  SubscriptionPeriod.swift
//  AppFoundation / PurchaseKit
//

/// 상품의 결제 주기. `.none` 은 일회성 상품(소비성/비소비성).
public enum SubscriptionPeriod: Sendable, Hashable {

    /// 반복 주기 없음 (일회성 상품).
    case none

    case weekly
    case monthly

    /// N 개월 주기 (분기 = `.months(3)`).
    case months(Int)

    case yearly

    /// 영구 (평생 이용권).
    case lifetime

    /// 판별 불가.
    case unknown
}
