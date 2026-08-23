//
//  StoreKitEntitlementResolver.swift
//  AppFoundation / PurchaseKit (StoreKit 백엔드)
//
//  활성 트랜잭션 스냅샷 + `EntitlementCatalog` → `CustomerInfo`. 순수 함수라 SDK 없이
//  테스트한다. StoreKit 에는 entitlement 개념이 없어 카탈로그가 권한의 유일한 출처다.
//

import Foundation

public enum StoreKitEntitlementResolver {

    /// - Parameters:
    ///   - transactions: `Transaction.currentEntitlements` 스냅샷 (상품당 최신 1건 가정이나
    ///     중복이 와도 가장 늦게 만료되는 것을 택한다).
    ///   - catalog: 권한 → 상품 매핑.
    ///   - appUserID: signIn 된 서비스 유저 id. nil = 익명.
    public static func resolve(
        transactions: [StoreKitTransactionSnapshot],
        catalog: EntitlementCatalog,
        appUserID: String?,
        now: Date = Date()
    ) -> CustomerInfo {

        // 상품별 대표 트랜잭션 — 활성 우선, 그 다음 만료가 늦은 것.
        var latestByProduct: [ProductIdentifier: StoreKitTransactionSnapshot] = [:]
        for tx in transactions {
            guard let existing = latestByProduct[tx.productIdentifier] else {
                latestByProduct[tx.productIdentifier] = tx
                continue
            }
            if rank(tx, now: now) > rank(existing, now: now) {
                latestByProduct[tx.productIdentifier] = tx
            }
        }

        var activeSubscriptions: Set<ProductIdentifier> = []
        var subscriptions: [ProductIdentifier: SubscriptionInfo] = [:]
        var entitlements: [EntitlementIdentifier: EntitlementInfo] = [:]

        for (productID, tx) in latestByProduct {
            let isActive = tx.isActive(at: now)

            if tx.productType.isSubscription {
                if isActive { activeSubscriptions.insert(productID) }
                subscriptions[productID] = SubscriptionInfo(
                    productIdentifier: productID,
                    paidPrice: tx.paidPrice,
                    currencyCode: tx.currencyCode,
                    isActive: isActive,
                    willRenew: tx.willRenew,
                    isSandbox: tx.isSandbox,
                    latestPurchasedAt: tx.purchasedAt,
                    originalPurchasedAt: tx.originalPurchasedAt,
                    expiresAt: tx.expiresAt,
                    revokedAt: tx.revokedAt
                )
            }

            guard isActive else { continue }
            for entitlementID in catalog.entitlements(for: productID) {
                // 같은 권한을 여러 상품이 줄 때 — 만료가 늦은(또는 비만료) 쪽이 대표.
                if let existing = entitlements[entitlementID],
                   !prefers(tx, over: existing) {
                    continue
                }
                entitlements[entitlementID] = EntitlementInfo(
                    identifier: entitlementID,
                    productIdentifier: productID,
                    isActive: true,
                    willRenew: tx.willRenew,
                    isSandbox: tx.isSandbox,
                    latestPurchasedAt: tx.purchasedAt,
                    originalPurchasedAt: tx.originalPurchasedAt,
                    expiresAt: tx.expiresAt,
                    revokedAt: tx.revokedAt
                )
            }
        }

        let id = appUserID ?? anonymousID
        return CustomerInfo(
            originalAppUserId: id,
            appUserId: id,
            isAnonymous: appUserID == nil,
            activeSubscriptions: activeSubscriptions,
            subscriptionsByProductIdentifier: subscriptions,
            activeEntitlements: entitlements
        )
    }

    /// 익명 고객의 표시용 id. StoreKit 은 익명 식별자를 발급하지 않는다.
    public static let anonymousID = "$StoreKitAnonymous"

    // MARK: - 비교

    private static func rank(_ tx: StoreKitTransactionSnapshot, now: Date) -> (Int, TimeInterval) {
        (tx.isActive(at: now) ? 1 : 0, tx.expiresAt?.timeIntervalSince1970 ?? .greatestFiniteMagnitude)
    }

    private static func prefers(_ tx: StoreKitTransactionSnapshot, over existing: EntitlementInfo) -> Bool {
        let candidate = tx.expiresAt?.timeIntervalSince1970 ?? .greatestFiniteMagnitude
        let current = existing.expiresAt?.timeIntervalSince1970 ?? .greatestFiniteMagnitude
        return candidate > current
    }
}
