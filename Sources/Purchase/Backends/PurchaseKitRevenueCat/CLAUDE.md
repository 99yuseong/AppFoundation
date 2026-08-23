# PurchaseKitRevenueCat

RevenueCat 실행 계층 — purchases-ios-spm 은 이 타깃만 소유한다. Doran
`Packages/Purchase` 의 RevenueCat 구현을 이식하고 sync/오퍼코드/attribution 을 더했다.
Swift 6 모드로 컴파일된다 (RevenueCat 5.x 는 Sendable 표기 충분).

## 구성

- `RevenueCatPurchaseService` + nested `Configuration(apiKey:, appUserID:, enableDebugLogs:)`.
  `configure()` 는 `Purchases.isConfigured` 로 멱등 — 앱이 `Purchases.configure` 를
  직접 부르지 않는다.
- `Mapping/` — RevenueCat → Public 모델 변환 extension (1 타입 1 파일). SDK 버전이 바뀌면
  여기만 손본다. PurchaseKit 과 RevenueCat 에 같은 이름(`CustomerInfo`·`EntitlementInfo`·
  `SubscriptionInfo`·`SubscriptionPeriod`)이 있어 **`PurchaseKit.` 한정이 필수**다.
- `PurchaseIntegration+RevenueCat` — `.mixpanel/.firebase/.amplitude` 는 전용
  attribution API, 그 외 키는 `$<key>_id` 구독자 속성으로 보낸다.

## 동작 메모

- 상품 조회는 `offerings.all` 전체 패키지를 스캔한다 (`.current` 한정 아님) — 어느
  오퍼링에 있든 식별자로 찾는다.
- 권한은 대시보드 entitlement 가 진실 — `EntitlementCatalog` 를 쓰지 않는다.
- `presentOfferCodeRedeemSheet` 는 `Purchases.presentCodeRedemptionSheet()` (MainActor).
- 에러는 `ErrorCode` 기준으로 `.cancelled`/`.purchasePending`/`.storeError` 정규화.
