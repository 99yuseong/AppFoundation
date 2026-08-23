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

    @Test("연산은 도착 순서대로 직렬 실행되고 겹치지 않는다")
    func operationsAreSerializedFIFO() async throws {
        let service = GatedPurchaseService()
        let manager = PurchaseSessionManager(purchaseService: service, userIDProvider: { "u1" })

        // 첫 login 이 signIn 안에서 멈춰 있는 동안 나머지를 순서대로 enqueue 한다.
        let first = Task { await manager.login(userID: "u1") }
        await service.waitUntilBlocked()
        let second = Task { await manager.logout() }
        try await Task.sleep(for: .milliseconds(20))
        let third = Task { await manager.login(userID: "u2") }
        try await Task.sleep(for: .milliseconds(20))

        #expect(await service.calls == ["signIn:u1"])   // 겹침 없음 — 뒤 연산은 대기 중

        await service.release()
        _ = await (first.value, second.value, third.value)

        #expect(await service.calls == ["signIn:u1", "signOut", "signIn:u2"])
        #expect(await service.appUserID == "u2")
    }

    @Test("유저 전환 중 signIn 실패 시 이전 identity 를 유지하지 않는다")
    func failedSwitchInvalidatesIdentity() async throws {
        let service = GatedPurchaseService()
        let manager = PurchaseSessionManager(purchaseService: service, userIDProvider: { "u2" })

        await service.release()
        await manager.login(userID: "u1")
        await service.failNextSignIn()
        await manager.login(userID: "u2")          // 실패 — 이전 u1 이 남으면 안 된다

        try await manager.ensureSignedIn()         // self-heal 로 u2 재시도
        #expect(await service.appUserID == "u2")
    }
}

/// signIn 을 게이트로 막을 수 있는 서비스 — 직렬화 순서 검증용.
private actor GatedPurchaseService: PurchaseService {

    private(set) var calls: [String] = []
    private var user: String?
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var blockedWaiters: [CheckedContinuation<Void, Never>] = []
    private var shouldFailNextSignIn = false

    struct Failure: Error {}

    func release() {
        isOpen = true
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }

    func failNextSignIn() { shouldFailNextSignIn = true }

    func waitUntilBlocked() async {
        guard waiters.isEmpty else { return }
        await withCheckedContinuation { blockedWaiters.append($0) }
    }

    private func gate() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
            blockedWaiters.forEach { $0.resume() }
            blockedWaiters.removeAll()
        }
    }

    var appUserID: String { user ?? "anonymous" }

    func configure() async -> CustomerInfo? { nil }

    func signIn(appUserID: String) async throws -> CustomerInfo {
        calls.append("signIn:\(appUserID)")
        await gate()
        if shouldFailNextSignIn {
            shouldFailNextSignIn = false
            throw Failure()
        }
        user = appUserID
        return .mockAnonymous
    }

    func signOut() async throws -> CustomerInfo {
        calls.append("signOut")
        user = nil
        return .mockAnonymous
    }

    nonisolated var customerInfoStream: AsyncStream<CustomerInfo> { AsyncStream { $0.finish() } }
    func refreshCustomerInfo() async throws -> CustomerInfo { .mockAnonymous }
    func products(of type: ProductType) async -> [ProductInfo] { [] }
    func product(for identifier: ProductIdentifier) async -> ProductInfo? { nil }
    func refreshProducts(of type: ProductType) async throws -> [ProductInfo] { [] }
    func purchase(_ product: ProductInfo) async throws -> CustomerInfo { .mockAnonymous }
    func restorePurchases() async throws -> CustomerInfo { .mockAnonymous }
    func syncPurchases() async throws -> CustomerInfo { .mockAnonymous }
    func showManageSubscriptions() async throws {}
    func presentOfferCodeRedeemSheet() async throws {}
    func setIntegrationID(_ id: String, for integration: PurchaseIntegration) async {}
}
