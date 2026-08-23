//
//  EntitlementInfo.swift
//  AppFoundation / PurchaseKit
//

import Foundation

/// 고객의 권한 하나의 상태.
///
/// "권한" 은 구매가 부여하는 접근(예: "plus")이다. 어떤 상품이 열었는지와 무관하게
/// 기능 게이팅은 이 단위로 한다.
public struct EntitlementInfo: Sendable, Hashable {

    public let identifier: EntitlementIdentifier

    /// 이 권한을 부여한 상품.
    public let productIdentifier: ProductIdentifier

    public let isActive: Bool

    /// 기간 만료 시 자동 갱신 여부.
    public let willRenew: Bool

    /// 샌드박스 구매 여부.
    public let isSandbox: Bool

    /// 최근 구매/갱신 시각.
    public let latestPurchasedAt: Date?

    /// 최초 구매 시각.
    public let originalPurchasedAt: Date?

    /// 만료 시각 (비만료 권한은 nil).
    public let expiresAt: Date?

    /// 해지/환불이 감지된 시각.
    public let revokedAt: Date?

    public init(
        identifier: EntitlementIdentifier,
        productIdentifier: ProductIdentifier,
        isActive: Bool,
        willRenew: Bool,
        isSandbox: Bool,
        latestPurchasedAt: Date?,
        originalPurchasedAt: Date?,
        expiresAt: Date?,
        revokedAt: Date?
    ) {
        self.identifier = identifier
        self.productIdentifier = productIdentifier
        self.isActive = isActive
        self.willRenew = willRenew
        self.isSandbox = isSandbox
        self.latestPurchasedAt = latestPurchasedAt
        self.originalPurchasedAt = originalPurchasedAt
        self.expiresAt = expiresAt
        self.revokedAt = revokedAt
    }
}
