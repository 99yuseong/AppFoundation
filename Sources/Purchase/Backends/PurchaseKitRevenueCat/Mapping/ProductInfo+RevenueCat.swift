//
//  ProductInfo+RevenueCat.swift
//  AppFoundation / PurchaseKitRevenueCat
//

import RevenueCat
import PurchaseKit

extension ProductInfo {

    init(revenueCat package: Package) {
        let product = package.storeProduct
        self.init(
            identifier: product.productIdentifier,
            type: ProductType(revenueCat: product.productType),
            period: PurchaseKit.SubscriptionPeriod(revenueCat: package),
            displayName: product.localizedTitle,
            description: product.localizedDescription,
            price: product.price,
            localizedPriceString: product.localizedPriceString,
            currencyCode: product.currencyCode
        )
    }
}
