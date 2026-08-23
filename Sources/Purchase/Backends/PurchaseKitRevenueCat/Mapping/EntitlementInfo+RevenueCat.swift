//
//  EntitlementInfo+RevenueCat.swift
//  AppFoundation / PurchaseKitRevenueCat
//

import RevenueCat
import PurchaseKit

extension PurchaseKit.EntitlementInfo {

    init(revenueCat rc: RevenueCat.EntitlementInfo) {
        self.init(
            identifier: rc.identifier,
            productIdentifier: rc.productIdentifier,
            isActive: rc.isActive,
            willRenew: rc.willRenew,
            isSandbox: rc.isSandbox,
            latestPurchasedAt: rc.latestPurchaseDate,
            originalPurchasedAt: rc.originalPurchaseDate,
            expiresAt: rc.expirationDate,
            revokedAt: rc.unsubscribeDetectedAt
        )
    }
}
