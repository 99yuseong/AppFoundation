# Purchase 도메인 — 개요·통합 가이드

Doran(`Packages/Purchase`)과 TumTumRead(`Domain/Purchase` + `Data/Purchase`)의 인앱결제
계층을 통합·일반화한 도메인. 계약은 `PurchaseKit`(SDK 무의존), 실행은 두 백엔드 —
`StoreKitPurchaseService`(StoreKit 2 순정, `PurchaseKit` 에 포함)와
`RevenueCatPurchaseService`(`PurchaseKitRevenueCat`).

## 백엔드 선택

| | StoreKit 2 순정 (`PurchaseKit`) | RevenueCat (`PurchaseKitRevenueCat`) |
|---|---|---|
| 외부 의존 | 없음 | purchases-ios-spm |
| 권한(entitlement) | 앱이 `EntitlementCatalog` 로 선언 | 대시보드 설정 |
| 계정 병합(익명→로그인) | ✕ (`appAccountToken` 만) | ○ (`logIn`) |
| 서버 검증·크로스플랫폼·웹훅 | 앱/서버가 직접 | RevenueCat 제공 |
| attribution 연동 | no-op | Mixpanel/Firebase/Amplitude… |
| 적합 | 단순 구독·단일 플랫폼·의존 최소화 | 서버 지급·분석 연동·다중 플랫폼 |

앱 코드는 `any PurchaseService` 에만 의존하므로 백엔드 교체 시 조립 한 줄만 바뀐다.

## 통합 순서

1. **product 추가**: `PurchaseKit` (+ RevenueCat 이면 `PurchaseKitRevenueCat`).
2. **권한 정의** (타입 안전):
   ```swift
   enum AppEntitlement: EntitlementIdentifier, EntitlementID, CaseIterable {
       case plus
       var entitlementID: EntitlementIdentifier { rawValue }
   }
   ```
3. **조립**:
   ```swift
   // StoreKit
   let purchase: any PurchaseService = StoreKitPurchaseService(configuration: .init(
       productIdentifiers: ["com.app.plus.monthly", "com.app.plus.yearly", "com.app.tip"],
       entitlements: EntitlementCatalog(["plus": ["com.app.plus.monthly", "com.app.plus.yearly"]])
   ))
   // RevenueCat
   let purchase: any PurchaseService = RevenueCatPurchaseService(configuration: .init(
       apiKey: Secrets.revenueCatKey, appUserID: cachedUserID, enableDebugLogs: isDebug
   ))
   ```
4. **세션 배선** — configure 는 세션 매니저가 1회 소유한다:
   ```swift
   let session = PurchaseSessionManager(
       purchaseService: purchase,
       userIDProvider: { try await auth.currentUserID() },        // 서버 id 원문
       validateUserID: { UUID(uuidString: $0) != nil }            // 검증만, 값은 원문
   )
   // 로그인·세션 복원 → session.login(userID:) / 로그아웃·탈퇴 → session.logout()
   // 상품 조회 전 → session.ensureConfigured() / 구매 직전 → try await session.ensureSignedIn()
   ```
5. **권한 관찰**: `for await info in purchase.customerInfoStream { isPlus = info.isEntitled(to: AppEntitlement.plus) }`
6. **상품 → 구매**: `let plans = await purchase.products(of: .autoRenewableSubscription)`;
   `try await purchase.purchase(plans[0])`. 취소는 `PurchaseError.isCancelled` 로 조용히 무시.
7. **오퍼 코드**: `try await purchase.presentOfferCodeRedeemSheet()` → 복귀 시
   `try await purchase.syncPurchases()`.

앱 고유 상품 개념(후원 등)은 앱 extension 으로:
```swift
extension ProductInfo { var isDonation: Bool { type == .consumable && identifier.contains("donation") } }
```

⚠️ **서버 사이드 지급 아키텍처**(서버가 결제 백엔드를 직접 조회해 재화를 발급 — Doran
iap-sync)에서는 `CustomerInfo` 권한으로 기능을 게이팅하지 말 것. 백엔드 값이 유일한 진실이다.

## 앱 마이그레이션 노트

### Doran (`Packages/Purchase` → `PurchaseKitRevenueCat`)
- 로컬 패키지 참조 제거 → `PurchaseKit` + `PurchaseKitRevenueCat` product 추가.
- `PurchaseServiceFactory.live()` → `RevenueCatPurchaseService(configuration: .init(apiKey:))`,
  `.mock(...)` → `MockPurchaseService(...)`.
- `configure(PurchaseConfiguration(...))` → `configure()` (설정은 init 으로 이동).
- `Data/Purchase/PurchaseSessionManager` → kit `PurchaseSessionManager` 로 교체:
  `CurrentUserIDProviding` 은 클로저로 감싸고 UUID 검증은 `validateUserID` 로 주입.
  `PurchaseSessionManaging`/`NoopPurchaseSessionManager` 이름 동일.
- `MockPurchaseService.entitlementForProduct` → `entitlements: EntitlementCatalog`.

### TumTumRead (`Domain/Purchase` + `Data/Purchase` → `PurchaseKitRevenueCat`)
- `ProductType.subscription` → `.autoRenewableSubscription` (또는 `type.isSubscription`),
  `.donation` → `.consumable` + `isDonation` 앱 extension (위 예시).
- `ProductInfo.name/decription/currency` → `displayName/description/currencyCode`.
- `CustomerInfo.entitlementsByIdentifier` → `activeEntitlements`;
  `plusEntitlement` → `entitlement(EntitlementType.plus)` (enum 에 `EntitlementID` 채택).
- `IAPError` → `PurchaseError` (`userCancelled` → `.cancelled`/`isCancelled`).
- `PurchaseRepository.configure(with:userId:)`/`configureAnonymous`/`configureLog` →
  `RevenueCatPurchaseService(configuration:)` + `configure()`.
- `integrate(.mixpanel(distinctId:))` → `setIntegrationID(distinctId, for: .mixpanel)`.
- `redeemOfferCode` 의 App Store URL 이동 → `presentOfferCodeRedeemSheet()`; 복귀 시
  `syncPurchases()` 는 그대로.
- **⚠️ identity**: 기존 고객이 `UUID.uuidString`(대문자)로 RevenueCat 에 등록돼 있다.
  kit 은 받은 문자열을 원문 그대로 넘기므로, TumTumRead 는 **계속 `uuidString` 을
  넘겨야** 고객이 갈라지지 않는다 (Doran 처럼 소문자 원문으로 바꾸면 안 된다).
- `PurchaseSubscriptionChecker`(AdConditionChecker 어댑터)는 TCA 의존이라 앱에 남긴다.
