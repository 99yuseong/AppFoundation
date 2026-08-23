import Foundation
import Testing
@testable import PurchaseKit

@Suite("Purchase session manager")
struct PurchaseSessionManagerTests {

    @Test("login 은 configure 후 signIn 하고 같은 id 재호출은 멱등이다")
    func loginIsIdempotent() async {
        let service = MockPurchaseService()
        let manager = PurchaseSessionManager(purchaseService: service, userIDProvider: { "u1" })

        await manager.login(userID: "u1")
        await manager.login(userID: "u1")

        #expect(await service.isConfiguredState)
        #expect(await service.appUserID == "u1")
    }

    @Test("logout 은 익명으로 되돌린다")
    func logoutReturnsAnonymous() async throws {
        let service = MockPurchaseService()
        let manager = PurchaseSessionManager(purchaseService: service, userIDProvider: { "u1" })

        await manager.login(userID: "u1")
        await manager.logout()

        #expect(try await service.refreshCustomerInfo().isAnonymous)
    }

    @Test("ensureSignedIn 은 미로그인 시 provider 로 self-heal 한다")
    func ensureSignedInSelfHeals() async throws {
        let service = MockPurchaseService()
        let manager = PurchaseSessionManager(purchaseService: service, userIDProvider: { "healed" })

        try await manager.ensureSignedIn()

        #expect(await service.appUserID == "healed")
    }

    @Test("검증 실패·provider 실패는 identityUnavailable")
    func identityUnavailable() async {
        struct NoUser: Error {}
        let failing = PurchaseSessionManager(purchaseService: MockPurchaseService(), userIDProvider: { throw NoUser() })
        await #expect(throws: PurchaseSessionError.identityUnavailable) {
            try await failing.ensureSignedIn()
        }

        let invalid = PurchaseSessionManager(
            purchaseService: MockPurchaseService(),
            userIDProvider: { "not-a-uuid" },
            validateUserID: { UUID(uuidString: $0) != nil }
        )
        await #expect(throws: PurchaseSessionError.identityUnavailable) {
            try await invalid.ensureSignedIn()
        }
    }

    @Test("동시 login/logout 은 호출 순서대로 직렬 반영된다")
    func concurrentCallsAreSerialized() async throws {
        let service = MockPurchaseService()
        let manager = PurchaseSessionManager(purchaseService: service, userIDProvider: { "u1" })

        async let a: Void = manager.login(userID: "u1")
        async let b: Void = manager.logout()
        async let c: Void = manager.login(userID: "u2")
        _ = await (a, b, c)

        #expect(await service.appUserID == "u2")
    }
}
