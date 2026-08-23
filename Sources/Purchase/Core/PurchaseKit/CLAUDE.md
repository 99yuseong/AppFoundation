# PurchaseKit

인앱결제 계약 계층. 외부 SDK 무의존 (CoreKit 만 의존 — `TopMostPresenter` 로 씬 조회).
타깃 `PurchaseKit` 은 이 폴더 + `Backends/PurchaseKitStoreKit`(StoreKit 2 순정, 시스템
프레임워크라 의존 zero) 을 함께 컴파일한다 — AuthKit = Core + REST 와 같은 구조.

## 폴더 구조 (서브도메인 단위 — 1 타입 1 파일)

```
Service/      PurchaseService(facade 계약) + PurchaseError
Product/      ProductInfo · ProductType(StoreKit 표준 4종) · SubscriptionPeriod · ProductIdentifier
Customer/     CustomerInfo · EntitlementID · EntitlementInfo · SubscriptionInfo · EntitlementCatalog
Session/      PurchaseSessionManaging + PurchaseSessionManager(actor) + Noop + Error
Integration/  PurchaseIntegration (개방형 String struct — 분석 도구 연동 키)
Mock/         MockPurchaseService(actor, public) + CustomerInfo/ProductInfo 샘플 값
```

## 공개 API

- `PurchaseService` — configure/signIn/signOut · customerInfoStream/refresh ·
  products/product/refreshProducts · purchase/restore/**sync** ·
  showManageSubscriptions/**presentOfferCodeRedeemSheet** · **setIntegrationID**.
  편의: `isEntitled(to:)`, `purchase(identifier:)`.
- `CustomerInfo.isEntitled(to:)` / `entitlement(_:)` — 기능 게이팅 단위. 앱은
  `EntitlementID` 채택 enum 으로 타입 안전하게 조회한다.
- `EntitlementCatalog` — 권한 → 상품 매핑. StoreKit 백엔드·Mock 의 권한 출처.
- `PurchaseSessionManager` — configure 1회 소유 + 계정 수명주기(login/logout) +
  구매 전 `ensureSignedIn` self-heal. 모든 연산 FIFO 직렬화(actor reentrancy 로
  SDK 상태와 기록이 어긋나 익명 구매→지급 누락이 나던 사고 클래스 방지).
- `MockPurchaseService` — 구매 시 카탈로그 권한 활성화. 기본 카탈로그 = 모든 상품 → "plus".

## 설계 결정 (변경 전에 읽을 것)

- **`configure()` 는 무인자.** 백엔드 설정(API 키·상품 id·카탈로그)은 각 구현의
  nested `Configuration` 이 init 으로 받는다 (`SupabaseAuthBackend.Configuration` 선례).
  RevenueCat 전용 개념(apiKey·offerings)을 계약에 새기지 않기 위해서다.
- **Factory 없음.** 백엔드가 별도 product 라 Core 가 `.live()` 를 만들 수 없다. 앱이
  `StoreKitPurchaseService(configuration:)` / `RevenueCatPurchaseService(configuration:)` /
  `MockPurchaseService(...)` 를 직접 생성한다 (AdKit 과 동일).
- **ProductType 은 StoreKit 표준 4종만.** "후원"·"Plus" 같은 앱 개념은 앱이
  `identifier` 로 분류한다 (`extension ProductInfo { var isDonation: Bool }`).
- **appUserID 는 원문 그대로.** RevenueCat app user id 는 대소문자 구분 — `UUID`
  왕복(`uuidString` 대문자화) 금지. 검증이 필요하면 `PurchaseSessionManager` 의
  `validateUserID` 클로저로 하고 값은 원문을 쓴다.
- **서버 사이드 지급 아키텍처에서는 entitlement 게이팅 금지.** 서버가 결제 백엔드를
  직접 조회해 재화를 발급하는 구조(Doran iap-sync)에서는 백엔드 값이 유일한 진실 —
  이 kit 은 식별·상품 조회·구매·복원 용도로만 쓴다.
- 페이월 뷰는 제공하지 않는다 — 앱이 facade 위에 자체 SwiftUI 화면을 그린다.
