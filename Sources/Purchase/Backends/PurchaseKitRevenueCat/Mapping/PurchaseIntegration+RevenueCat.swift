//
//  PurchaseIntegration+RevenueCat.swift
//  AppFoundation / PurchaseKitRevenueCat
//

import RevenueCat
import PurchaseKit

extension PurchaseIntegration {

    /// 알려진 연동은 전용 attribution API 로, 모르는 키는 `$<key>_id` 구독자 속성으로 보낸다.
    func apply(id: String, to attribution: Attribution) {
        switch self {
        case .mixpanel: attribution.setMixpanelDistinctID(id)
        case .firebase: attribution.setFirebaseAppInstanceID(id)
        case .amplitude: attribution.setAmplitudeUserID(id)
        default: attribution.setAttributes(["$\(rawValue)_id": id])
        }
    }
}
