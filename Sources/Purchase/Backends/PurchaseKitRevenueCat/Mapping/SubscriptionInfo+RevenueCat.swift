//
//  SubscriptionInfo+RevenueCat.swift
//  AppFoundation / PurchaseKitRevenueCat
//

import Foundation
import RevenueCat
import PurchaseKit

extension PurchaseKit.SubscriptionInfo {

    init(revenueCat rc: RevenueCat.SubscriptionInfo) {
        self.init(
            productIdentifier: rc.productIdentifier,
            paidPrice: rc.price.map { Decimal($0.amount) },
            currencyCode: rc.price?.currency,
            isActive: rc.isActive,
            willRenew: rc.willRenew,
            isSandbox: rc.isSandbox,
            latestPurchasedAt: rc.purchaseDate,
            originalPurchasedAt: rc.originalPurchaseDate,
            expiresAt: rc.expiresDate,
            revokedAt: rc.unsubscribeDetectedAt
        )
    }
}
