//
//  SubscriptionPeriod+StoreKit.swift
//  AppFoundation / PurchaseKit (StoreKit 백엔드)
//

import StoreKit

extension SubscriptionPeriod {

    /// 구독 정보가 없으면 `.none`(일회성). 주 단위·N개월·연 단위를 분류한다.
    init(storeKit product: Product) {
        guard let period = product.subscription?.subscriptionPeriod else {
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
