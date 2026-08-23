//
//  ProductType+StoreKit.swift
//  AppFoundation / PurchaseKit (StoreKit 백엔드)
//

import StoreKit

extension ProductType {

    /// `Product.ProductType` → kit 분류. 알 수 없는 값은 비소비성으로 접는다.
    init(storeKit type: Product.ProductType) {
        switch type {
        case .consumable: self = .consumable
        case .nonConsumable: self = .nonConsumable
        case .autoRenewable: self = .autoRenewableSubscription
        case .nonRenewable: self = .nonRenewableSubscription
        default: self = .nonConsumable
        }
    }
}
