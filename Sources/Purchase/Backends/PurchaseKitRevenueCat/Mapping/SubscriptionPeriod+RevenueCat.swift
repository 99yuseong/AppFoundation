//
//  SubscriptionPeriod+RevenueCat.swift
//  AppFoundation / PurchaseKitRevenueCat
//

import RevenueCat
import PurchaseKit

extension PurchaseKit.SubscriptionPeriod {

    /// `packageType == .lifetime` 은 주기가 없어 먼저 잡는다. 나머지는 상품의 구독 주기로 분류.
    init(revenueCat package: Package) {
        if package.packageType == .lifetime {
            self = .lifetime
            return
        }
        guard let period = package.storeProduct.subscriptionPeriod else {
            self = .none
            return
        }
        switch (period.unit, period.value) {
        case (.week, _): self = .weekly
        case (.day, 7): self = .weekly
        case (.month, 1): self = .monthly
        case (.month, let n): self = .months(n)
        case (.year, _): self = .yearly
        default: self = .unknown
        }
    }
}
