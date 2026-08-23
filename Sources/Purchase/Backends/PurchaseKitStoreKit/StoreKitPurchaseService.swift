//
//  StoreKitPurchaseService.swift
//  AppFoundation / PurchaseKit (StoreKit 백엔드)
//
//  StoreKit 2 순정 `PurchaseService`. 외부 SDK 없음. 권한은 `Configuration.entitlements`
//  카탈로그로 파생하고, 서버 영수증 검증은 범위 밖이다(필요하면 앱이 `Transaction`
//  JWS 를 서버로 보낸다 — 이 kit 은 기기 로컬 검증(`.verified`)만 신뢰한다).
//

import Foundation
import StoreKit
import CoreKit

public actor StoreKitPurchaseService: PurchaseService {

    public struct Configuration: Sendable {

        /// App Store Connect 에 등록한 상품 id 전부. StoreKit 은 오퍼링 개념이 없어
        /// 앱이 목록을 준다.
        public let productIdentifiers: Set<ProductIdentifier>

        /// 권한 → 상품 매핑. 비어 있으면 `activeEntitlements` 가 항상 비어 `isEntitled` 는
        /// false 다 — 구독 게이팅을 쓰려면 반드시 채운다.
        public let entitlements: EntitlementCatalog

        public init(
            productIdentifiers: Set<ProductIdentifier>,
            entitlements: EntitlementCatalog = .empty
        ) {
            self.productIdentifiers = productIdentifiers
            self.entitlements = entitlements
        }
    }

    private let configuration: Configuration

    private var isConfigured = false
    private var cachedProducts: [ProductIdentifier: Product] = [:]
    private var signedInUserID: String?
    private var updatesTask: Task<Void, Never>?
    private var continuations: [UUID: AsyncStream<CustomerInfo>.Continuation] = [:]

    public init(configuration: Configuration) {
        self.configuration = configuration
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: 부팅·식별

    public var appUserID: String {
        signedInUserID ?? StoreKitEntitlementResolver.anonymousID
    }

    @discardableResult
    public func configure() async -> CustomerInfo? {
        guard !isConfigured else { return await currentCustomerInfo() }
        isConfigured = true

        // 이전 실행에서 finish 못 한 트랜잭션을 먼저 닫는다.
        for await result in Transaction.unfinished {
            if case .verified(let tx) = result { await tx.finish() }
        }

        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let tx) = result { await tx.finish() }
                await self.emitCurrent()
            }
        }

        return await currentCustomerInfo()
    }

    /// StoreKit 은 계정 병합이 없다 — id 를 기억해 이후 구매의 `appAccountToken`(UUID 파싱
    /// 가능할 때)으로 붙이고 `CustomerInfo.appUserId` 로 돌려준다.
    @discardableResult
    public func signIn(appUserID: String) async throws -> CustomerInfo {
        signedInUserID = appUserID
        let info = await currentCustomerInfo()
        emit(info)
        return info
    }

    @discardableResult
    public func signOut() async throws -> CustomerInfo {
        signedInUserID = nil
        let info = await currentCustomerInfo()
        emit(info)
        return info
    }

    // MARK: 고객 정보

    public nonisolated var customerInfoStream: AsyncStream<CustomerInfo> {
        AsyncStream { continuation in
            let id = UUID()
            Task { await self.register(continuation, id: id) }
            continuation.onTermination = { _ in
                Task { await self.unregister(id) }
            }
        }
    }

    @discardableResult
    public func refreshCustomerInfo() async throws -> CustomerInfo {
        try ensureConfigured()
        return await currentCustomerInfo()
    }

    // MARK: 상품

    public func products(of type: ProductType) async -> [ProductInfo] {
        if cachedProducts.isEmpty { _ = try? await loadProducts() }
        return cachedProducts.values
            .map(ProductInfo.init(storeKit:))
            .filter { $0.type == type }
            .sorted { $0.identifier < $1.identifier }
    }

    public func product(for identifier: ProductIdentifier) async -> ProductInfo? {
        if cachedProducts.isEmpty { _ = try? await loadProducts() }
        return cachedProducts[identifier].map(ProductInfo.init(storeKit:))
    }

    public func refreshProducts(of type: ProductType) async throws -> [ProductInfo] {
        try await loadProducts()
            .map(ProductInfo.init(storeKit:))
            .filter { $0.type == type }
            .sorted { $0.identifier < $1.identifier }
    }

    // MARK: 구매·복원·동기화

    @discardableResult
    public func purchase(_ product: ProductInfo) async throws -> CustomerInfo {
        try ensureConfigured()
        guard let skProduct = await storeProduct(for: product.identifier) else {
            throw PurchaseError.productNotFound(product.identifier)
        }

        var options: Set<Product.PurchaseOption> = []
        if let userID = signedInUserID, let token = UUID(uuidString: userID) {
            options.insert(.appAccountToken(token))
        }

        let result: Product.PurchaseResult
        do {
            result = try await skProduct.purchase(options: options)
        } catch {
            throw PurchaseError(storeKit: error)
        }

        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let tx):
                await tx.finish()
            case .unverified(_, let error):
                throw PurchaseError.storeError(message: "Unverified transaction: \(error.localizedDescription)")
            }
            let info = await currentCustomerInfo()
            emit(info)
            return info
        case .userCancelled:
            throw PurchaseError.cancelled
        case .pending:
            throw PurchaseError.purchasePending
        @unknown default:
            throw PurchaseError.storeError(message: "Unknown purchase result")
        }
    }

    @discardableResult
    public func restorePurchases() async throws -> CustomerInfo {
        try await syncPurchases()
    }

    @discardableResult
    public func syncPurchases() async throws -> CustomerInfo {
        try ensureConfigured()
        do {
            try await AppStore.sync()
        } catch {
            throw PurchaseError(storeKit: error)
        }
        let info = await currentCustomerInfo()
        emit(info)
        return info
    }

    // MARK: 시스템 UI

    public func showManageSubscriptions() async throws {
        let scene = await MainActor.run { TopMostPresenter.keyWindow()?.windowScene }
        guard let scene else { throw PurchaseError.noActiveScene }
        do {
            try await AppStore.showManageSubscriptions(in: scene)
        } catch {
            throw PurchaseError(storeKit: error)
        }
    }

    public func presentOfferCodeRedeemSheet() async throws {
        let scene = await MainActor.run { TopMostPresenter.keyWindow()?.windowScene }
        guard let scene else { throw PurchaseError.noActiveScene }
        do {
            try await AppStore.presentOfferCodeRedeemSheet(in: scene)
        } catch {
            throw PurchaseError(storeKit: error)
        }
    }

    // MARK: 분석 연동 — StoreKit 에는 attribution 개념이 없다.

    public func setIntegrationID(_ id: String, for integration: PurchaseIntegration) async {}

    // MARK: - 내부

    private func ensureConfigured() throws {
        guard isConfigured else { throw PurchaseError.notConfigured }
    }

    @discardableResult
    private func loadProducts() async throws -> [Product] {
        do {
            let products = try await Product.products(for: configuration.productIdentifiers)
            cachedProducts = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
            return products
        } catch {
            throw PurchaseError(storeKit: error)
        }
    }

    private func storeProduct(for identifier: ProductIdentifier) async -> Product? {
        if let cached = cachedProducts[identifier] { return cached }
        _ = try? await loadProducts()
        return cachedProducts[identifier]
    }

    /// `Transaction.currentEntitlements` 를 스냅샷으로 뽑아 카탈로그로 권한을 파생한다.
    private func currentCustomerInfo() async -> CustomerInfo {
        var snapshots: [StoreKitTransactionSnapshot] = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result else { continue }
            let willRenew = await willAutoRenew(productID: tx.productID)
            snapshots.append(StoreKitTransactionSnapshot(storeKit: tx, willRenew: willRenew))
        }
        return StoreKitEntitlementResolver.resolve(
            transactions: snapshots,
            catalog: configuration.entitlements,
            appUserID: signedInUserID
        )
    }

    /// 구독 그룹 상태에서 이 상품의 자동 갱신 여부. 구독이 아니거나 조회 실패면 false.
    private func willAutoRenew(productID: ProductIdentifier) async -> Bool {
        guard let product = await storeProduct(for: productID),
              let subscription = product.subscription,
              let statuses = try? await subscription.status
        else { return false }

        for status in statuses {
            guard case .verified(let renewal) = status.renewalInfo else { continue }
            if renewal.currentProductID == productID { return renewal.willAutoRenew }
        }
        return false
    }

    // MARK: 스트림 배선

    private func register(_ continuation: AsyncStream<CustomerInfo>.Continuation, id: UUID) {
        continuations[id] = continuation
    }

    private func unregister(_ id: UUID) {
        continuations[id] = nil
    }

    private func emitCurrent() async {
        emit(await currentCustomerInfo())
    }

    private func emit(_ info: CustomerInfo) {
        for continuation in continuations.values {
            continuation.yield(info)
        }
    }
}
