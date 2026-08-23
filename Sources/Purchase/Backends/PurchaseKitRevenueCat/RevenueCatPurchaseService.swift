//
//  RevenueCatPurchaseService.swift
//  AppFoundation / PurchaseKitRevenueCat
//
//  RevenueCat 기반 `PurchaseService`. RevenueCat 을 import 하는 파일은 이 타깃뿐이다.
//  Doran Packages/Purchase 의 RevenueCatPurchaseService 이식 (+ sync/오퍼코드/attribution).
//

import Foundation
import RevenueCat
import PurchaseKit

public final class RevenueCatPurchaseService: PurchaseService {

    public struct Configuration: Sendable {

        /// RevenueCat public SDK key.
        public let apiKey: String

        /// 부팅 시 이미 아는 안정적 app user id (캐시된 서비스 유저 id). nil = 익명 시작.
        /// 원문 그대로 전달된다 (대소문자 구분).
        public let appUserID: String?

        /// SDK 상세 로그. 빌드 플래그에 연결한다.
        public let enableDebugLogs: Bool

        public init(apiKey: String, appUserID: String? = nil, enableDebugLogs: Bool = false) {
            self.apiKey = apiKey
            self.appUserID = appUserID
            self.enableDebugLogs = enableDebugLogs
        }
    }

    private let configuration: Configuration

    public init(configuration: Configuration) {
        self.configuration = configuration
    }

    // MARK: 부팅·식별

    public var appUserID: String {
        get async { Purchases.isConfigured ? Purchases.shared.appUserID : "" }
    }

    @discardableResult
    public func configure() async -> PurchaseKit.CustomerInfo? {
        guard !Purchases.isConfigured else {
            return Purchases.shared.cachedCustomerInfo.map(currentInfo)
        }
        Purchases.logLevel = configuration.enableDebugLogs ? .debug : .info

        let purchases: Purchases
        if let appUserID = configuration.appUserID {
            purchases = Purchases.configure(withAPIKey: configuration.apiKey, appUserID: appUserID)
        } else {
            purchases = Purchases.configure(withAPIKey: configuration.apiKey)
        }
        return purchases.cachedCustomerInfo.map(currentInfo)
    }

    @discardableResult
    public func signIn(appUserID: String) async throws -> PurchaseKit.CustomerInfo {
        do {
            let (info, _) = try await Purchases.shared.logIn(appUserID)
            return currentInfo(info)
        } catch {
            throw PurchaseError(revenueCat: error)
        }
    }

    @discardableResult
    public func signOut() async throws -> PurchaseKit.CustomerInfo {
        do {
            let info = try await Purchases.shared.logOut()
            return currentInfo(info)
        } catch {
            throw PurchaseError(revenueCat: error)
        }
    }

    // MARK: 고객 정보

    public var customerInfoStream: AsyncStream<PurchaseKit.CustomerInfo> {
        AsyncStream { continuation in
            let task = Task {
                for await info in Purchases.shared.customerInfoStream {
                    continuation.yield(self.currentInfo(info))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    @discardableResult
    public func refreshCustomerInfo() async throws -> PurchaseKit.CustomerInfo {
        do {
            return currentInfo(try await Purchases.shared.customerInfo(fetchPolicy: .fetchCurrent))
        } catch {
            throw PurchaseError(revenueCat: error)
        }
    }

    // MARK: 상품

    public func products(of type: ProductType) async -> [ProductInfo] {
        if let cached = Purchases.shared.cachedOfferings {
            return products(in: cached, of: type)
        }
        guard let offerings = try? await Purchases.shared.offerings() else { return [] }
        return products(in: offerings, of: type)
    }

    public func product(for identifier: ProductIdentifier) async -> ProductInfo? {
        await package(for: identifier).map(ProductInfo.init(revenueCat:))
    }

    public func refreshProducts(of type: ProductType) async throws -> [ProductInfo] {
        do {
            return products(in: try await Purchases.shared.offerings(), of: type)
        } catch {
            throw PurchaseError(revenueCat: error)
        }
    }

    // MARK: 구매·복원·동기화

    @discardableResult
    public func purchase(_ product: ProductInfo) async throws -> PurchaseKit.CustomerInfo {
        guard let package = await package(for: product.identifier) else {
            throw PurchaseError.productNotFound(product.identifier)
        }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled { throw PurchaseError.cancelled }
            return currentInfo(result.customerInfo)
        } catch {
            throw PurchaseError(revenueCat: error)
        }
    }

    @discardableResult
    public func restorePurchases() async throws -> PurchaseKit.CustomerInfo {
        do {
            return currentInfo(try await Purchases.shared.restorePurchases())
        } catch {
            throw PurchaseError(revenueCat: error)
        }
    }

    @discardableResult
    public func syncPurchases() async throws -> PurchaseKit.CustomerInfo {
        do {
            return currentInfo(try await Purchases.shared.syncPurchases())
        } catch {
            throw PurchaseError(revenueCat: error)
        }
    }

    // MARK: 시스템 UI

    public func showManageSubscriptions() async throws {
        do {
            try await Purchases.shared.showManageSubscriptions()
        } catch {
            throw PurchaseError(revenueCat: error)
        }
    }

    public func presentOfferCodeRedeemSheet() async throws {
        await MainActor.run { Purchases.shared.presentCodeRedemptionSheet() }
    }

    // MARK: 분석 연동

    public func setIntegrationID(_ id: String, for integration: PurchaseIntegration) async {
        integration.apply(id: id, to: Purchases.shared.attribution)
    }

    // MARK: - 내부

    private func currentInfo(_ rc: RevenueCat.CustomerInfo) -> PurchaseKit.CustomerInfo {
        PurchaseKit.CustomerInfo(revenueCat: rc, appUserID: Purchases.shared.appUserID, isAnonymous: Purchases.shared.isAnonymous)
    }

    /// 모든 오퍼링(`.current` 만이 아니라)의 패키지 — 어느 오퍼링에 있든 찾는다.
    private func packages(in offerings: Offerings) -> [Package] {
        offerings.all.values.flatMap(\.availablePackages)
    }

    private func products(in offerings: Offerings, of type: ProductType) -> [ProductInfo] {
        packages(in: offerings).map(ProductInfo.init(revenueCat:)).filter { $0.type == type }
    }

    private func package(for identifier: ProductIdentifier) async -> Package? {
        if let cached = Purchases.shared.cachedOfferings,
           let match = packages(in: cached).first(where: { $0.storeProduct.productIdentifier == identifier }) {
            return match
        }
        guard let offerings = try? await Purchases.shared.offerings() else { return nil }
        return packages(in: offerings).first { $0.storeProduct.productIdentifier == identifier }
    }
}
