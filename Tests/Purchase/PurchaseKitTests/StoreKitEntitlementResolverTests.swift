import Foundation
import Testing
@testable import PurchaseKit

@Suite("StoreKit entitlement resolver")
struct StoreKitEntitlementResolverTests {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let catalog = EntitlementCatalog([
        "plus": ["sub.monthly", "sub.yearly"],
        "pro": ["sub.yearly"],
    ])

    private func tx(
        _ id: ProductIdentifier,
        type: ProductType = .autoRenewableSubscription,
        expiresIn: TimeInterval? = 3_600,
        revoked: Bool = false,
        willRenew: Bool = true
    ) -> StoreKitTransactionSnapshot {
        StoreKitTransactionSnapshot(
            productIdentifier: id,
            productType: type,
            purchasedAt: now.addingTimeInterval(-60),
            originalPurchasedAt: now.addingTimeInterval(-60),
            expiresAt: expiresIn.map { now.addingTimeInterval($0) },
            revokedAt: revoked ? now.addingTimeInterval(-1) : nil,
            isSandbox: true,
            willRenew: willRenew,
            paidPrice: 4_400,
            currencyCode: "KRW"
        )
    }

    @Test("활성 구독이 카탈로그의 권한을 전부 연다")
    func activeSubscriptionGrantsEntitlements() {
        let info = StoreKitEntitlementResolver.resolve(
            transactions: [tx("sub.yearly")], catalog: catalog, appUserID: "user-1", now: now
        )
        #expect(info.isEntitled(to: "plus"))
        #expect(info.isEntitled(to: "pro"))
        #expect(info.activeSubscriptions == ["sub.yearly"])
        #expect(info.subscriptionsByProductIdentifier["sub.yearly"]?.willRenew == true)
        #expect(info.appUserId == "user-1")
        #expect(info.isAnonymous == false)
    }

    @Test("만료·환불된 트랜잭션은 권한을 주지 않지만 구독 이력엔 남는다")
    func expiredAndRevokedAreInactive() {
        let info = StoreKitEntitlementResolver.resolve(
            transactions: [tx("sub.monthly", expiresIn: -1), tx("sub.yearly", revoked: true)],
            catalog: catalog, appUserID: nil, now: now
        )
        #expect(info.hasAnyActiveEntitlement == false)
        #expect(info.activeSubscriptions.isEmpty)
        #expect(info.subscriptionsByProductIdentifier["sub.monthly"]?.isActive == false)
        #expect(info.subscriptionsByProductIdentifier["sub.yearly"]?.revokedAt != nil)
        #expect(info.isAnonymous)
    }

    @Test("한 권한을 여러 상품이 줄 때 만료가 늦은 상품이 대표가 된다")
    func longestExpiryRepresentsEntitlement() {
        let info = StoreKitEntitlementResolver.resolve(
            transactions: [tx("sub.monthly", expiresIn: 3_600), tx("sub.yearly", expiresIn: 86_400)],
            catalog: catalog, appUserID: nil, now: now
        )
        #expect(info.entitlement("plus")?.productIdentifier == "sub.yearly")
    }

    @Test("비만료 비소비성은 권한만 열고 구독 목록엔 없다")
    func nonConsumableLifetime() {
        let catalog = EntitlementCatalog(["plus": ["lifetime"]])
        let info = StoreKitEntitlementResolver.resolve(
            transactions: [tx("lifetime", type: .nonConsumable, expiresIn: nil)],
            catalog: catalog, appUserID: nil, now: now
        )
        #expect(info.isEntitled(to: "plus"))
        #expect(info.entitlement("plus")?.expiresAt == nil)
        #expect(info.activeSubscriptions.isEmpty)
    }

    @Test("카탈로그 밖 구독은 activeSubscriptions 에만 반영된다")
    func subscriptionOutsideCatalog() {
        let info = StoreKitEntitlementResolver.resolve(
            transactions: [tx("sub.other")], catalog: catalog, appUserID: nil, now: now
        )
        #expect(info.activeSubscriptions == ["sub.other"])
        #expect(info.hasAnyActiveEntitlement == false)
    }

    @Test("비갱신 구독은 만료를 모르면 권한을 열지 않는다")
    func nonRenewingWithoutExpiryIsInactive() {
        let catalog = EntitlementCatalog(["plus": ["pass"]])
        let unknown = StoreKitEntitlementResolver.resolve(
            transactions: [tx("pass", type: .nonRenewableSubscription, expiresIn: nil)],
            catalog: catalog, appUserID: nil, now: now
        )
        #expect(unknown.hasAnyActiveEntitlement == false)

        let known = StoreKitEntitlementResolver.resolve(
            transactions: [tx("pass", type: .nonRenewableSubscription, expiresIn: 3_600)],
            catalog: catalog, appUserID: nil, now: now
        )
        #expect(known.isEntitled(to: "plus"))
    }
}
