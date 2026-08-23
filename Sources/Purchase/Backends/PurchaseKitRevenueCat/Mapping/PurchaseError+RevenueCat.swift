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
        } else if let code = Self.errorCode(of: error) {
            switch code {
            case .purchaseCancelledError: self = .cancelled
            case .paymentPendingError: self = .purchasePending
            default: self = .storeError(message: error.localizedDescription)
            }
        } else {
            self = .unknown(error)
        }
    }

    /// RevenueCat 은 보통 `ErrorCode` 값이 아니라 같은 도메인의 `NSError`(`PublicError`)를
    /// 던진다 — 둘 다 `ErrorCode` 로 되돌린다.
    private static func errorCode(of error: Error) -> ErrorCode? {
        if let code = error as? ErrorCode { return code }
        let nsError = error as NSError
        guard nsError.domain == ErrorCode.errorDomain else { return nil }
        return ErrorCode(rawValue: nsError.code)
    }
}
