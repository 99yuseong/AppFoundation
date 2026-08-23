//
//  ProductInfo.swift
//  AppFoundation / PurchaseKit
//

import Foundation

/// 구매 가능한 상품의 SDK 무의존 스냅샷.
///
/// 페이월 UI 에 필요한 것만 담는다 — SDK 의 `Package`/`Product` 객체는 노출하지 않는다.
/// 백엔드는 구매 시점에 `identifier` 로 SDK 객체를 다시 찾는다.
public struct ProductInfo: Sendable, Hashable, Identifiable {

    /// 스토어 상품 식별자. `Identifiable.id` 이기도 하다.
    public let identifier: ProductIdentifier

    /// StoreKit 상품 분류.
    public let type: ProductType

    /// 결제 주기 (`.none` = 일회성).
    public let period: SubscriptionPeriod

    /// 현지화된 표시 이름.
    public let displayName: String

    /// 현지화된 설명.
    public let description: String

    /// 스토어 현지 통화 기준 가격.
    public let price: Decimal

    /// 통화 서식이 적용된 가격 문자열 (예: "₩4,400").
    public let localizedPriceString: String

    /// ISO 통화 코드 (예: "KRW").
    public let currencyCode: String?

    public var id: ProductIdentifier { identifier }

    public init(
        identifier: ProductIdentifier,
        type: ProductType,
        period: SubscriptionPeriod,
        displayName: String,
        description: String,
        price: Decimal,
        localizedPriceString: String,
        currencyCode: String?
    ) {
        self.identifier = identifier
        self.type = type
        self.period = period
        self.displayName = displayName
        self.description = description
        self.price = price
        self.localizedPriceString = localizedPriceString
        self.currencyCode = currencyCode
    }
}
