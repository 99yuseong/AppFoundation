//
//  ProductInfo+StoreKit.swift
//  AppFoundation / PurchaseKit (StoreKit 백엔드)
//

import StoreKit

extension ProductInfo {

    init(storeKit product: Product) {
        self.init(
            identifier: product.id,
            type: ProductType(storeKit: product.type),
            period: SubscriptionPeriod(storeKit: product),
            displayName: product.displayName,
            description: product.description,
            price: product.price,
            localizedPriceString: product.displayPrice,
            currencyCode: product.priceFormatStyle.currencyCode
        )
    }
}
