//
//  PurchaseService.swift
//  AppFoundation / PurchaseKit
//
//  인앱결제 facade. 앱은 이 프로토콜과 SDK 무의존 모델에만 의존한다.
//  구현: `StoreKitPurchaseService`(PurchaseKit 포함, 의존 zero),
//  `RevenueCatPurchaseService`(PurchaseKitRevenueCat), `MockPurchaseService`(프리뷰·테스트).
//  백엔드 설정(API 키, 상품 id 목록)은 각 구현의 init 이 받는다 — 이 계약에는 없다.
//

import Foundation

/// 인앱결제 진입점: 부팅·식별·상품 조회·구매·복원·권한 관찰.
///
/// 구매/복원 결과는 항상 최신 ``CustomerInfo`` 다. 기능 게이팅은 상품이 아니라
/// `customerInfo.isEntitled(to:)` 로 한다.
///
/// - Note: 위 권한 게이팅 지침은 결제 백엔드가 진실일 때만 해당한다. **서버 사이드
///   지급 아키텍처** — 서버가 결제 백엔드를 직접 조회해 재화·구독 상태를 자체 발급
///   (Doran `iap-sync`: 티켓 잔액, `ad_free_until`) — 에서는 ``CustomerInfo`` 권한으로
///   게이팅하지 말고, 이 서비스는 식별(`signIn`/`signOut`)·상품 조회·구매·복원에만 쓴다.
public protocol PurchaseService: Sendable {

    // MARK: 부팅·식별

    /// 결제 백엔드가 현재 동작 중인 app user id.
    var appUserID: String { get async }

    /// 백엔드를 부팅한다. 멱등 — 두 번째 호출부터는 no-op. 가능한 한 일찍 호출.
    /// 로컬 캐시된 ``CustomerInfo`` 가 있으면 반환해 오프라인에서도 게이팅 UI 를
    /// 그릴 수 있게 한다 (네트워크 갱신은 ``customerInfoStream`` 으로 온다).
    @discardableResult
    func configure() async -> CustomerInfo?

    /// 안정적인 app user id(로그인 후 서비스 유저 id)로 고객을 식별한다.
    ///
    /// - Important: id 는 백엔드에 **원문 그대로** 전달된다 — RevenueCat app user id 는
    ///   대소문자를 구분한다. 서버가 내려준 문자열을 가공 없이 넘기고, `UUID` 왕복
    ///   (`uuidString` 은 대문자화)은 금지다. 익명 구매 병합은 백엔드 지원 범위에 따른다
    ///   (RevenueCat ○, StoreKit ✕ — StoreKit 은 이후 구매의 `appAccountToken` 으로만 쓴다).
    @discardableResult
    func signIn(appUserID: String) async throws -> CustomerInfo

    /// 현재 식별을 버리고 익명 ``CustomerInfo`` 를 돌려준다.
    @discardableResult
    func signOut() async throws -> CustomerInfo

    // MARK: 고객 정보

    /// 구매·권한이 바뀔 때마다 새 ``CustomerInfo`` 를 방출한다. 권한 상태는 이 스트림으로 구동.
    var customerInfoStream: AsyncStream<CustomerInfo> { get }

    /// 네트워크 갱신을 강제하고 최신 ``CustomerInfo`` 를 돌려준다.
    @discardableResult
    func refreshCustomerInfo() async throws -> CustomerInfo

    // MARK: 상품

    /// 분류별 상품 — 캐시 우선, 캐시 미스면 네트워크.
    func products(of type: ProductType) async -> [ProductInfo]

    /// 식별자로 상품 하나 — 캐시 우선. 없으면 nil.
    func product(for identifier: ProductIdentifier) async -> ProductInfo?

    /// 상품 목록을 네트워크에서 강제 갱신한 뒤 분류별로 돌려준다.
    func refreshProducts(of type: ProductType) async throws -> [ProductInfo]

    // MARK: 구매·복원·동기화

    /// 상품 구매. 모든 ``ProductType`` 공용 — 상품의 의미(구독·코인·후원)는 앱이 정한다.
    /// 사용자가 시트를 닫으면 ``PurchaseError/cancelled``.
    @discardableResult
    func purchase(_ product: ProductInfo) async throws -> CustomerInfo

    /// 이전 구매를 복원하고 갱신된 ``CustomerInfo`` 를 돌려준다.
    @discardableResult
    func restorePurchases() async throws -> CustomerInfo

    /// 앱 외부에서 완료된 구매(프로모션/오퍼 코드, 가족 공유)를 반영한다.
    /// 오퍼 코드 등록 후 앱으로 복귀했을 때 호출한다.
    @discardableResult
    func syncPurchases() async throws -> CustomerInfo

    // MARK: 시스템 UI

    /// 시스템 "구독 관리" 시트. 이미 present 된 화면이 있으면 가려질 수 있다.
    func showManageSubscriptions() async throws

    /// 시스템 오퍼 코드 등록 시트. 등록 결과는 ``customerInfoStream`` / ``syncPurchases()`` 로 반영된다.
    func presentOfferCodeRedeemSheet() async throws

    // MARK: 분석 연동

    /// 분석 도구의 사용자 id 를 결제 백엔드에 연결한다 (RevenueCat attribution).
    /// 연동 개념이 없는 백엔드(StoreKit)는 no-op.
    func setIntegrationID(_ id: String, for integration: PurchaseIntegration) async
}

// MARK: - 편의

public extension PurchaseService {

    /// 최신 ``CustomerInfo`` 를 받아 권한 활성 여부를 돌려준다.
    func isEntitled(to id: some EntitlementID) async throws -> Bool {
        try await refreshCustomerInfo().isEntitled(to: id)
    }

    /// 식별자로 상품을 찾아 구매. 없으면 ``PurchaseError/productNotFound(_:)``.
    @discardableResult
    func purchase(identifier: ProductIdentifier) async throws -> CustomerInfo {
        guard let product = await product(for: identifier) else {
            throw PurchaseError.productNotFound(identifier)
        }
        return try await purchase(product)
    }
}
