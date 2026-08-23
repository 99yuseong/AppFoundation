//
//  CustomerInfo+Mock.swift
//  AppFoundation / PurchaseKit
//
//  프리뷰·테스트용 샘플 값. 앱이 스토어 SDK 없이 페이월 프리뷰를 만들 수 있게 public.
//

import Foundation

public extension CustomerInfo {

    /// 구매 없는 익명 고객.
    static let mockAnonymous = CustomerInfo(
        originalAppUserId: "$RCAnonymousID:mock",
        appUserId: "$RCAnonymousID:mock",
        isAnonymous: true,
        activeSubscriptions: [],
        subscriptionsByProductIdentifier: [:],
        activeEntitlements: [:]
    )

    /// `entitlementID`(기본 "plus") 권한이 활성인 고객 — 유료 상태 프리뷰.
    static func mockEntitled(
        to entitlementID: EntitlementIdentifier = "plus",
        productIdentifier: ProductIdentifier = "mock.subscription.monthly"
    ) -> CustomerInfo {
        CustomerInfo(
            originalAppUserId: "mock-user",
            appUserId: "mock-user",
            isAnonymous: false,
            activeSubscriptions: [productIdentifier],
            subscriptionsByProductIdentifier: [:],
            activeEntitlements: [
                entitlementID: EntitlementInfo(
                    identifier: entitlementID,
                    productIdentifier: productIdentifier,
                    isActive: true,
                    willRenew: true,
                    isSandbox: true,
                    latestPurchasedAt: Date(),
                    originalPurchasedAt: Date(),
                    expiresAt: Date().addingTimeInterval(60 * 60 * 24 * 30),
                    revokedAt: nil
                )
            ]
        )
    }
}
