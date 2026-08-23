//
//  ProductType.swift
//  AppFoundation / PurchaseKit
//
//  StoreKit 표준 상품 분류 4종. kit 은 이 4종만 안다 — "후원", "Plus 티어" 같은 앱
//  개념은 앱이 `ProductInfo.identifier` 를 보고 위에 얹는다 (docs/purchase 참조).
//

/// App Store 상품 분류 4종 (`StoreKit.Product.ProductType` 과 1:1).
public enum ProductType: String, Sendable, Hashable, CaseIterable {

    /// 소진 후 재구매 가능 (코인, 힌트, 일회성 후원).
    case consumable

    /// 1회 구매·영구 소유 (광고 제거, 평생 잠금해제).
    case nonConsumable

    /// 자동 갱신 구독.
    case autoRenewableSubscription

    /// 수동 갱신 정기권 (시즌 패스).
    case nonRenewableSubscription
}

public extension ProductType {

    /// 구독류 여부 — UI 에서 "반복 결제인가?" 를 한 번에 묻는 용도.
    var isSubscription: Bool {
        switch self {
        case .autoRenewableSubscription, .nonRenewableSubscription: return true
        case .consumable, .nonConsumable: return false
        }
    }
}
