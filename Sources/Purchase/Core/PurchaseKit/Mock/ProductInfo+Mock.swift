//
//  ProductInfo+Mock.swift
//  AppFoundation / PurchaseKit
//

import Foundation

public extension ProductInfo {

    /// 월간 자동 갱신 구독 샘플.
    static let mockMonthly = ProductInfo(
        identifier: "mock.subscription.monthly",
        type: .autoRenewableSubscription,
        period: .monthly,
        displayName: "Monthly Plus",
        description: "Unlock everything, billed monthly.",
        price: 4_400,
        localizedPriceString: "₩4,400",
        currencyCode: "KRW"
    )

    /// 연간 자동 갱신 구독 샘플.
    static let mockYearly = ProductInfo(
        identifier: "mock.subscription.yearly",
        type: .autoRenewableSubscription,
        period: .yearly,
        displayName: "Yearly Plus",
        description: "Unlock everything, billed yearly.",
        price: 44_000,
        localizedPriceString: "₩44,000",
        currencyCode: "KRW"
    )

    /// 소비성 샘플 (일회성 후원).
    static let mockConsumable = ProductInfo(
        identifier: "mock.consumable.tip",
        type: .consumable,
        period: .none,
        displayName: "Tip",
        description: "Say thanks with a small tip.",
        price: 1_100,
        localizedPriceString: "₩1,100",
        currencyCode: "KRW"
    )
}
