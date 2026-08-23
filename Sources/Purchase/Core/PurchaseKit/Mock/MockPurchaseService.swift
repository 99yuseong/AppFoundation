//
//  MockPurchaseService.swift
//  AppFoundation / PurchaseKit
//
//  인메모리 `PurchaseService` — 프리뷰·단위테스트·오프라인 개발용. 구매하면 카탈로그가
//  정한 권한이 활성화돼 페이월/게이팅 흐름을 끝까지 검증할 수 있다.
//

import Foundation

public actor MockPurchaseService: PurchaseService {

    private var products: [ProductInfo]
    private var customerInfo: CustomerInfo
    private let catalog: EntitlementCatalog
    private var isConfigured = false
    private var continuations: [UUID: AsyncStream<CustomerInfo>.Continuation] = [:]

    /// - Parameters:
    ///   - products: `products(of:)` / `product(for:)` 가 돌려줄 카탈로그.
    ///   - customerInfo: 초기 고객 스냅샷.
    ///   - entitlements: 상품 → 권한 매핑. 기본값은 모든 상품이 "plus" 를 준다.
    public init(
        products: [ProductInfo] = [],
        customerInfo: CustomerInfo = .mockAnonymous,
        entitlements: EntitlementCatalog? = nil
    ) {
        self.products = products
        self.customerInfo = customerInfo
        self.catalog = entitlements
            ?? EntitlementCatalog(["plus": Set(products.map(\.identifier))])
    }

    // MARK: 부팅·식별

    public var appUserID: String { customerInfo.appUserId }

    /// 테스트용 — `configure()` 호출 여부.
    public var isConfiguredState: Bool { isConfigured }

    public func configure() async -> CustomerInfo? {
        isConfigured = true
        return customerInfo
    }

    public func signIn(appUserID: String) async throws -> CustomerInfo {
        customerInfo = CustomerInfo(
            originalAppUserId: customerInfo.originalAppUserId,
            appUserId: appUserID,
            isAnonymous: false,
            activeSubscriptions: customerInfo.activeSubscriptions,
            subscriptionsByProductIdentifier: customerInfo.subscriptionsByProductIdentifier,
            activeEntitlements: customerInfo.activeEntitlements
        )
        emit()
        return customerInfo
    }

    public func signOut() async throws -> CustomerInfo {
        customerInfo = .mockAnonymous
        emit()
        return customerInfo
    }

    // MARK: 고객 정보

    public nonisolated var customerInfoStream: AsyncStream<CustomerInfo> {
        AsyncStream { continuation in
            let id = UUID()
            let registration = Task { await self.register(continuation, id: id) }
            continuation.onTermination = { _ in
                registration.cancel()
                Task { await self.unregister(id) }
            }
        }
    }

    public func refreshCustomerInfo() async throws -> CustomerInfo { customerInfo }

    // MARK: 상품

    public func products(of type: ProductType) async -> [ProductInfo] {
        products.filter { $0.type == type }
    }

    public func product(for identifier: ProductIdentifier) async -> ProductInfo? {
        products.first { $0.identifier == identifier }
    }

    public func refreshProducts(of type: ProductType) async throws -> [ProductInfo] {
        products.filter { $0.type == type }
    }

    // MARK: 구매·복원·동기화

    public func purchase(_ product: ProductInfo) async throws -> CustomerInfo {
        let now = Date()
        var entitlements = customerInfo.activeEntitlements
        for entitlementID in catalog.entitlements(for: product.identifier) {
            entitlements[entitlementID] = EntitlementInfo(
                identifier: entitlementID,
                productIdentifier: product.identifier,
                isActive: true,
                willRenew: product.type == .autoRenewableSubscription,
                isSandbox: true,
                latestPurchasedAt: now,
                originalPurchasedAt: now,
                expiresAt: product.type.isSubscription ? now.addingTimeInterval(60 * 60 * 24 * 30) : nil,
                revokedAt: nil
            )
        }
        var subscriptions = customerInfo.activeSubscriptions
        if product.type.isSubscription { subscriptions.insert(product.identifier) }

        customerInfo = CustomerInfo(
            originalAppUserId: customerInfo.originalAppUserId,
            appUserId: customerInfo.appUserId,
            isAnonymous: customerInfo.isAnonymous,
            activeSubscriptions: subscriptions,
            subscriptionsByProductIdentifier: customerInfo.subscriptionsByProductIdentifier,
            activeEntitlements: entitlements
        )
        emit()
        return customerInfo
    }

    public func restorePurchases() async throws -> CustomerInfo { customerInfo }

    public func syncPurchases() async throws -> CustomerInfo { customerInfo }

    // MARK: 시스템 UI·연동

    public func showManageSubscriptions() async throws {}

    public func presentOfferCodeRedeemSheet() async throws {}

    public func setIntegrationID(_ id: String, for integration: PurchaseIntegration) async {}

    // MARK: 스트림 배선

    private func register(_ continuation: AsyncStream<CustomerInfo>.Continuation, id: UUID) {
        // 등록 전에 스트림이 종료됐으면(onTermination 선행) 보관하지 않는다 — 누수 방지.
        guard !Task.isCancelled else { return }
        continuations[id] = continuation
        continuation.yield(customerInfo)
    }

    private func unregister(_ id: UUID) {
        continuations[id] = nil
    }

    private func emit() {
        for continuation in continuations.values {
            continuation.yield(customerInfo)
        }
    }
}
