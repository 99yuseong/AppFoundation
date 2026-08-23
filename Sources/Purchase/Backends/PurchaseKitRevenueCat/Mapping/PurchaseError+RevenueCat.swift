//
//  PurchaseError+RevenueCat.swift
//  AppFoundation / PurchaseKitRevenueCat
//

import Foundation
import RevenueCat
import PurchaseKit

extension PurchaseError {

    /// RevenueCat/StoreKit 에러를 kit 에러로 정규화한다.
    init(revenueCat error: Error) {
        if let error = error as? PurchaseError {
            self = error
        } else if let code = error as? ErrorCode {
            switch code {
            case .purchaseCancelledError: self = .cancelled
            case .paymentPendingError: self = .purchasePending
            default: self = .storeError(message: code.localizedDescription)
            }
        } else if (error as NSError).domain == ErrorCode.errorDomain {
            self = .storeError(message: error.localizedDescription)
        } else {
            self = .unknown(error)
        }
    }
}
