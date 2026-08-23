//
//  EntitlementID.swift
//  AppFoundation / PurchaseKit
//
//  타입 안전 권한 식별자. 앱은 자기 권한 집합을 `EntitlementID` 채택 enum 으로 정의해
//  `customerInfo.isEntitled(to: AppEntitlement.plus)` 처럼 조회한다 — 문자열 키가
//  앱 전체에 흩어지지 않는다.
//

/// 백엔드에 설정된 권한 식별자 원문 (RevenueCat entitlement id, 또는 StoreKit 백엔드의
/// `EntitlementCatalog` 키).
public typealias EntitlementIdentifier = String

/// 권한을 지칭할 수 있는 모든 것.
///
/// ```swift
/// enum AppEntitlement: EntitlementIdentifier, EntitlementID, CaseIterable {
///     case plus
///     var entitlementID: EntitlementIdentifier { rawValue }
/// }
/// ```
/// `String` 도 채택하므로 런타임에 식별자만 아는 호출부도 같은 API 를 쓴다.
public protocol EntitlementID {
    var entitlementID: EntitlementIdentifier { get }
}

extension String: EntitlementID {
    public var entitlementID: EntitlementIdentifier { self }
}
