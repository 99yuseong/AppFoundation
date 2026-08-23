# PurchaseKitStoreKit

StoreKit 2 순정 `PurchaseService` 구현. 외부 SDK 없음 — **`PurchaseKit` 타깃에 포함**된다
(폴더만 분리, Package.swift 에서 타깃 path 를 `Sources/Purchase` 로 올림).

## 구성

- `StoreKitPurchaseService` (actor) + nested `Configuration(productIdentifiers:, entitlements:,
  nonRenewingDurations:, consumableFulfillment:)`. StoreKit 은 오퍼링이 없어 앱이 상품 id 전부를 준다.
  - `nonRenewingDurations` — 비갱신 구독은 StoreKit 이 만료일을 주지 않는다. 기간 미설정
    상품은 권한을 열지 않는다 (영구 권한 오인 방지).
  - `consumableFulfillment` — 소비성 트랜잭션은 이 훅이 true 를 돌려줄 때만 finish 한다.
    서버 지급 구조에서 지급 전 finish 하면 크래시 시 재화가 유실된다. nil = 즉시 finish.
- `Mapping/` — `Product` → `ProductInfo`/`ProductType`/`SubscriptionPeriod`,
  `Transaction` → `StoreKitTransactionSnapshot`, StoreKit 에러 → `PurchaseError`.
- `Support/` — `StoreKitTransactionSnapshot`(값 타입) + `StoreKitEntitlementResolver`
  (순수 함수: 스냅샷 + `EntitlementCatalog` → `CustomerInfo`). SDK 객체는 테스트에서 만들 수
  없어 권한 파생을 값 타입으로 떼어 테스트한다 (`Tests/Purchase/PurchaseKitTests`).

## 의미 매핑 (RevenueCat 과 다른 점)

- **권한**: `Transaction.currentEntitlements` + 카탈로그로 파생. 카탈로그가 비면
  `isEntitled` 는 항상 false. 같은 권한을 여러 상품이 주면 만료가 늦은 쪽이 대표.
- **identity**: 계정 병합이 없다. `signIn` 은 id 를 기억해 `CustomerInfo.appUserId` 로
  돌려주고, UUID 파싱이 되면 이후 구매에 `appAccountToken` 으로 붙인다. 익명 표시 id 는
  `StoreKitEntitlementResolver.anonymousID`.
- **복원/동기화**: 둘 다 `AppStore.sync()` — 사용자에게 App Store 로그인 시트가 뜰 수 있다.
- **시스템 UI**: `showManageSubscriptions`/`presentOfferCodeRedeemSheet` 는 `UIWindowScene`
  이 필요 — `TopMostPresenter.keyWindow()?.windowScene`, 없으면 `.noActiveScene`.
- **attribution**: 개념이 없어 `setIntegrationID` 는 no-op.
- **검증**: 기기 로컬 `.verified` 만 신뢰. `.unverified` 는 `.storeError`. 서버 영수증
  검증은 범위 밖 — 필요하면 앱이 JWS 를 서버로 보낸다.
- `configure()` 는 in-flight Task 를 공유해 재진입 호출이 설정 완료를 기다린다.
  `Transaction.unfinished` 를 finish(소비성은 훅 통과 시)하고 `Transaction.updates` 리스너를
  시작한다. 리스너는 갱신·환불·가족공유 변화를 `customerInfoStream` 으로 흘린다.
