//
//  PurchaseError+StoreKit.swift
//  AppFoundation / PurchaseKit (StoreKit 백엔드)
//

import StoreKit

extension PurchaseError {

    /// StoreKit 에러를 kit 에러로 정규화한다.
    init(storeKit error: Error) {
        if let error = error as? PurchaseError {
            self = error
        } else if let skError = error as? StoreKitError {
            switch skError {
            case .userCancelled: self = .cancelled
            default: self = .storeError(message: skError.localizedDescription)
            }
        } else if let purchaseError = error as? Product.PurchaseError {
            self = .storeError(message: purchaseError.localizedDescription)
        } else {
            self = .unknown(error)
        }
    }
}
