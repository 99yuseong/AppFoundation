//
//  StoreKitTransactionSnapshot.swift
//  AppFoundation / PurchaseKit (StoreKit 백엔드)
//
//  `StoreKit.Transaction` 의 값 스냅샷. SDK 객체는 테스트에서 만들 수 없으므로
//  권한 파생(`StoreKitEntitlementResolver`)은 이 값 타입만 입력으로 받는다.
//

import Foundation

public struct StoreKitTransactionSnapshot: Sendable, Hashable {

    public let productIdentifier: ProductIdentifier
    public let productType: ProductType
    public let purchasedAt: Date
    public let originalPurchasedAt: Date
    public let expiresAt: Date?
    public let revokedAt: Date?
    public let isSandbox: Bool
    /// 갱신 정보(구독 그룹 상태)에서 얻는다 — 비구독은 false.
    public let willRenew: Bool
    public let paidPrice: Decimal?
    public let currencyCode: String?

    public init(
        productIdentifier: ProductIdentifier,
        productType: ProductType,
        purchasedAt: Date,
        originalPurchasedAt: Date,
        expiresAt: Date?,
        revokedAt: Date?,
        isSandbox: Bool,
        willRenew: Bool,
        paidPrice: Decimal?,
        currencyCode: String?
    ) {
        self.productIdentifier = productIdentifier
        self.productType = productType
        self.purchasedAt = purchasedAt
        self.originalPurchasedAt = originalPurchasedAt
        self.expiresAt = expiresAt
        self.revokedAt = revokedAt
        self.isSandbox = isSandbox
        self.willRenew = willRenew
        self.paidPrice = paidPrice
        self.currencyCode = currencyCode
    }

    /// 환불/해지 전이고 만료 전이면 활성.
    public func isActive(at now: Date) -> Bool {
        guard revokedAt == nil else { return false }
        guard let expiresAt else { return true }
        return expiresAt > now
    }
}
