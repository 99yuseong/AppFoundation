import Testing
@testable import PurchaseKit

// 앱이 정의하는 권한 타입 — 소비 앱과 동일한 형태.
private enum AppEntitlement: EntitlementIdentifier, EntitlementID, CaseIterable {
    case plus
    var entitlementID: EntitlementIdentifier { rawValue }
}

@Suite("Mock purchase flow")
struct MockPurchaseFlowTests {

    @Test("상품은 StoreKit 분류로 필터된다")
    func productsByType() async {
        let service = MockPurchaseService(products: [.mockMonthly, .mockYearly, .mockConsumable])
        #expect(await service.products(of: .autoRenewableSubscription).count == 2)
        #expect(await service.products(of: .consumable).count == 1)
    }

    @Test("구독 구매가 카탈로그의 권한을 활성화한다")
    func purchaseGrantsEntitlement() async throws {
        let service = MockPurchaseService(products: [.mockMonthly])

        let before = try await service.refreshCustomerInfo()
        #expect(before.isEntitled(to: AppEntitlement.plus) == false)

        let after = try await service.purchase(.mockMonthly)
        #expect(after.isEntitled(to: AppEntitlement.plus))
        #expect(after.activeSubscriptions.contains(ProductInfo.mockMonthly.identifier))
    }

    @Test("카탈로그 밖 상품은 권한을 주지 않는다")
    func purchaseOutsideCatalog() async throws {
        let service = MockPurchaseService(
            products: [.mockMonthly, .mockConsumable],
            entitlements: EntitlementCatalog(["plus": [ProductInfo.mockMonthly.identifier]])
        )
        let info = try await service.purchase(.mockConsumable)
        #expect(info.hasAnyActiveEntitlement == false)
    }

    @Test("String·typed 권한 조회가 일치한다")
    func entitlementLookup() {
        let info = CustomerInfo.mockEntitled(to: "plus")
        #expect(info.isEntitled(to: "plus"))
        #expect(info.isEntitled(to: AppEntitlement.plus))
        #expect(info.hasAnyActiveEntitlement)
    }

    @Test("signOut 은 권한 없는 익명으로 돌아간다")
    func signOutClearsEntitlements() async throws {
        let service = MockPurchaseService(products: [.mockMonthly], customerInfo: .mockEntitled(to: "plus"))
        let info = try await service.signOut()
        #expect(info.isAnonymous)
        #expect(info.hasAnyActiveEntitlement == false)
    }
}
