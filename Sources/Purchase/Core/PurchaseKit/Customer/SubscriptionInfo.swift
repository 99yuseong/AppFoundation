//
//  SubscriptionInfo.swift
//  AppFoundation / PurchaseKit
//

import Foundation

/// 고객이 보유한 구독 상품 하나의 구매/갱신 상태.
public struct SubscriptionInfo: Sendable, Hashable {

    public let productIdentifier: ProductIdentifier

    /// 결제 금액 (알 수 있을 때).
    public let paidPrice: Decimal?

    /// `paidPrice` 의 ISO 통화 코드.
    public let currencyCode: String?

    public let isActive: Bool
    public let willRenew: Bool
    public let isSandbox: Bool

    public let latestPurchasedAt: Date?
    public let originalPurchasedAt: Date?
    public let expiresAt: Date?
    public let revokedAt: Date?

    public init(
        productIdentifier: ProductIdentifier,
        paidPrice: Decimal?,
        currencyCode: String?,
        isActive: Bool,
        willRenew: Bool,
        isSandbox: Bool,
        latestPurchasedAt: Date?,
        originalPurchasedAt: Date?,
        expiresAt: Date?,
        revokedAt: Date?
    ) {
        self.productIdentifier = productIdentifier
        self.paidPrice = paidPrice
        self.currencyCode = currencyCode
        self.isActive = isActive
        self.willRenew = willRenew
        self.isSandbox = isSandbox
        self.latestPurchasedAt = latestPurchasedAt
        self.originalPurchasedAt = originalPurchasedAt
        self.expiresAt = expiresAt
        self.revokedAt = revokedAt
    }
}
