//
//  CustomerInfo+RevenueCat.swift
//  AppFoundation / PurchaseKitRevenueCat
//

import RevenueCat
import PurchaseKit

extension PurchaseKit.CustomerInfo {

    init(revenueCat rc: RevenueCat.CustomerInfo, appUserID: String, isAnonymous: Bool) {
        self.init(
            originalAppUserId: rc.originalAppUserId,
            appUserId: appUserID,
            isAnonymous: isAnonymous,
            activeSubscriptions: rc.activeSubscriptions,
            subscriptionsByProductIdentifier: rc.subscriptionsByProductIdentifier
                .mapValues(PurchaseKit.SubscriptionInfo.init(revenueCat:)),
            activeEntitlements: rc.entitlements.active
                .mapValues(PurchaseKit.EntitlementInfo.init(revenueCat:))
        )
    }
}
