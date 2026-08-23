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

        /// 비갱신 구독의 유효 기간. StoreKit 은 비갱신 구독의 만료일을 주지 않으므로 앱이
        /// 상품별 기간을 선언한다. 없는 상품은 권한을 열지 않는다.
        public let nonRenewingDurations: [ProductIdentifier: TimeInterval]

        /// 소비성 트랜잭션 지급 훅. 검증된 소비성 트랜잭션(구매 직후·앱 재시작 시 미완료·
        /// 외부 갱신)마다 호출되며, **true 를 돌려줘야 finish** 한다 — 서버 지급이 끝나기 전에
        /// finish 하면 크래시 시 재화가 유실된다. nil = 즉시 finish (로컬 지급 구조).
        public let consumableFulfillment: (@Sendable (StoreKitTransactionSnapshot) async -> Bool)?

        public init(
            productIdentifiers: Set<ProductIdentifier>,
            entitlements: EntitlementCatalog = .empty,
            nonRenewingDurations: [ProductIdentifier: TimeInterval] = [:],
            consumableFulfillment: (@Sendable (StoreKitTransactionSnapshot) async -> Bool)? = nil
        ) {
            self.productIdentifiers = productIdentifiers
            self.entitlements = entitlements
            self.nonRenewingDurations = nonRenewingDurations
            self.consumableFulfillment = consumableFulfillment
        }
    }

    private let configuration: Configuration

    /// 부팅 in-flight. 완료 전 재진입 호출은 같은 Task 를 기다린다 — 반쯤 설정된 상태를 보지 않는다.
    private var configureTask: Task<CustomerInfo?, Never>?
    private var isConfigured: Bool { configureTask != nil }
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
        if let configureTask { return await configureTask.value }

        let task = Task<CustomerInfo?, Never> {
            // 이전 실행에서 finish 못 한 트랜잭션을 먼저 닫는다 (소비성은 지급 훅 통과 시에만).
            for await result in Transaction.unfinished {
                if case .verified(let tx) = result { await self.settle(tx) }
            }

            // 갱신·환불·가족공유·외부 구매를 스트림으로 흘린다.
            self.updatesTask = Task { [weak self] in
                for await result in Transaction.updates {
                    guard let self else { return }
                    if case .verified(let tx) = result { await self.settle(tx) }
                    await self.emitCurrent()
                }
            }
            return await self.currentCustomerInfo()
        }
        configureTask = task
        return await task.value
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
            let registration = Task { await self.register(continuation, id: id) }
            continuation.onTermination = { _ in
                registration.cancel()
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
                await settle(tx)
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

    /// 검증된 트랜잭션을 마무리한다. 소비성은 지급 훅이 true 일 때만 finish — 미완료로 남겨
    /// 다음 실행의 `Transaction.unfinished` 에서 재시도되게 한다.
    private func settle(_ tx: Transaction) async {
        if ProductType(storeKit: tx.productType) == .consumable,
           let fulfill = configuration.consumableFulfillment {
            let snapshot = StoreKitTransactionSnapshot(storeKit: tx, willRenew: false, nonRenewingDuration: nil)
            guard await fulfill(snapshot) else { return }
        }
        await tx.finish()
    }

    /// `Transaction.currentEntitlements` 를 스냅샷으로 뽑아 카탈로그로 권한을 파생한다.
    private func currentCustomerInfo() async -> CustomerInfo {
        var snapshots: [StoreKitTransactionSnapshot] = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result else { continue }
            let willRenew = await willAutoRenew(productID: tx.productID)
            snapshots.append(StoreKitTransactionSnapshot(
                storeKit: tx,
                willRenew: willRenew,
                nonRenewingDuration: configuration.nonRenewingDurations[tx.productID]
            ))
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
        // 등록 전에 스트림이 종료됐으면(onTermination 선행) 보관하지 않는다 — 누수 방지.
        guard !Task.isCancelled else { return }
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
