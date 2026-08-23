//
//  StoreKitTransactionSnapshot+StoreKit.swift
//  AppFoundation / PurchaseKit (StoreKit 백엔드)
//

import Foundation
import StoreKit

extension StoreKitTransactionSnapshot {

    /// - Parameters:
    ///   - willRenew: 구독 그룹 갱신 정보에서 별도로 조회해 넘긴다 (트랜잭션엔 없다).
    ///   - nonRenewingDuration: 비갱신 구독은 StoreKit 이 만료일을 주지 않는다 — 앱이 준
    ///     기간으로 `purchaseDate + duration` 을 만료로 삼는다. nil 이면 만료 불명.
    init(storeKit tx: Transaction, willRenew: Bool, nonRenewingDuration: TimeInterval?) {
        let type = ProductType(storeKit: tx.productType)
        let expiresAt: Date?
        if type == .nonRenewableSubscription {
            expiresAt = nonRenewingDuration.map { tx.purchaseDate.addingTimeInterval($0) }
        } else {
            expiresAt = tx.expirationDate
        }
        self.init(
            productIdentifier: tx.productID,
            productType: type,
            purchasedAt: tx.purchaseDate,
            originalPurchasedAt: tx.originalPurchaseDate,
            expiresAt: expiresAt,
            revokedAt: tx.revocationDate,
            isSandbox: tx.environment == .sandbox,
            willRenew: willRenew,
            paidPrice: tx.price,
            currencyCode: tx.currency?.identifier
        )
    }
}
