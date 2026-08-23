//
//  EntitlementCatalog.swift
//  AppFoundation / PurchaseKit
//
//  "어떤 상품이 어떤 권한을 주는가" 의 선언. StoreKit 에는 entitlement 개념이 없어
//  StoreKit 백엔드·Mock 은 이 카탈로그로 `CustomerInfo.activeEntitlements` 를 파생한다.
//  RevenueCat 백엔드는 대시보드가 진실이라 카탈로그를 쓰지 않는다.
//

/// 권한 → 그 권한을 부여하는 상품 집합.
public struct EntitlementCatalog: Sendable, Hashable {

    public let productsByEntitlement: [EntitlementIdentifier: Set<ProductIdentifier>]

    public init(_ productsByEntitlement: [EntitlementIdentifier: Set<ProductIdentifier>]) {
        self.productsByEntitlement = productsByEntitlement
    }

    /// 빈 카탈로그 — 어떤 상품도 권한을 주지 않는다.
    public static let empty = EntitlementCatalog([:])

    /// 상품이 부여하는 권한들 (정렬 안정성을 위해 식별자 순).
    public func entitlements(for product: ProductIdentifier) -> [EntitlementIdentifier] {
        productsByEntitlement
            .filter { $0.value.contains(product) }
            .map(\.key)
            .sorted()
    }
}
