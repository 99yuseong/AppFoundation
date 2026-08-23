//
//  CustomerInfo.swift
//  AppFoundation / PurchaseKit
//

import Foundation

/// 현재 고객의 구매·권한 스냅샷. SDK 무의존 값 타입 — `PurchaseService` 가 만든다.
public struct CustomerInfo: Sendable, Hashable {

    /// 최초로 관측된 app user id.
    public let originalAppUserId: String

    /// 이 스냅샷이 속한 app user id.
    public let appUserId: String

    /// 익명(미식별) 고객 여부.
    public let isAnonymous: Bool

    /// 현재 활성 구독의 상품 식별자.
    public let activeSubscriptions: Set<ProductIdentifier>

    /// 상품 식별자별 구독 상태.
    public let subscriptionsByProductIdentifier: [ProductIdentifier: SubscriptionInfo]

    /// 활성 권한 (권한 식별자 키).
    public let activeEntitlements: [EntitlementIdentifier: EntitlementInfo]

    public init(
        originalAppUserId: String,
        appUserId: String,
        isAnonymous: Bool,
        activeSubscriptions: Set<ProductIdentifier>,
        subscriptionsByProductIdentifier: [ProductIdentifier: SubscriptionInfo],
        activeEntitlements: [EntitlementIdentifier: EntitlementInfo]
    ) {
        self.originalAppUserId = originalAppUserId
        self.appUserId = appUserId
        self.isAnonymous = isAnonymous
        self.activeSubscriptions = activeSubscriptions
        self.subscriptionsByProductIdentifier = subscriptionsByProductIdentifier
        self.activeEntitlements = activeEntitlements
    }
}

// MARK: - 권한 조회

public extension CustomerInfo {

    /// `id` 권한 정보 (활성 여부 무관). 앱 정의 `EntitlementID` 또는 `String`.
    func entitlement(_ id: some EntitlementID) -> EntitlementInfo? {
        activeEntitlements[id.entitlementID]
    }

    /// 권한이 현재 활성인지.
    func isEntitled(to id: some EntitlementID) -> Bool {
        activeEntitlements[id.entitlementID]?.isActive ?? false
    }

    /// 어떤 권한이든 활성인지 — "이 고객이 무언가에 돈을 내고 있는가".
    var hasAnyActiveEntitlement: Bool {
        activeEntitlements.values.contains { $0.isActive }
    }
}
