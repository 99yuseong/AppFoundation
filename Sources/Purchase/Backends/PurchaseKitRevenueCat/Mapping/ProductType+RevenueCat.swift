//
//  ProductType+RevenueCat.swift
//  AppFoundation / PurchaseKitRevenueCat
//

import RevenueCat
import PurchaseKit

extension ProductType {

    init(revenueCat type: StoreProduct.ProductType) {
        switch type {
        case .consumable: self = .consumable
        case .nonConsumable: self = .nonConsumable
        case .autoRenewableSubscription: self = .autoRenewableSubscription
        case .nonRenewableSubscription: self = .nonRenewableSubscription
        @unknown default: self = .nonConsumable
        }
    }
}
