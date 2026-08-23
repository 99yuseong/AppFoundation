//
//  StoreKitTransactionSnapshot+StoreKit.swift
//  AppFoundation / PurchaseKit (StoreKit 백엔드)
//

import StoreKit

extension StoreKitTransactionSnapshot {

    /// - Parameter willRenew: 구독 그룹 갱신 정보에서 별도로 조회해 넘긴다 (트랜잭션엔 없다).
    init(storeKit tx: Transaction, willRenew: Bool) {
        self.init(
            productIdentifier: tx.productID,
            productType: ProductType(storeKit: tx.productType),
            purchasedAt: tx.purchaseDate,
            originalPurchasedAt: tx.originalPurchaseDate,
            expiresAt: tx.expirationDate,
            revokedAt: tx.revocationDate,
            isSandbox: tx.environment == .sandbox,
            willRenew: willRenew,
            paidPrice: tx.price,
            currencyCode: tx.currency?.identifier
        )
    }
}
