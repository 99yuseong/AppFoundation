# AdKitAdMob

Google Mobile Ads(AdMob) 실행 계층 — GoogleMobileAds SDK 는 이 타깃만 소유한다.
TumTumRead AdFeature + Doran AdKit 의 로더·뷰를 placement-generic 으로 일반화해
이식했다.

## 네이밍·파일 규칙

public 타입은 전부 `AdMob` 접두 + `{광고 단위}{기능}` 순
(예: `AdMobNativeAdCachedLoader`) — 자동완성·정렬이 백엔드→단위→기능으로
그룹핑된다. 로더 설정은 각 로더의 nested `Configuration`
(`Configuration()` == `.default` 가 되도록 memberwise 기본값을 유지할 것).
새 타입은 반드시 자기 파일로 만든다 (1 타입 1 파일, nested 타입 제외).

## 구성

- `AdMobConfigurator` — SDK 시작·테스트 기기 등록·오디오 세션 관리 opt-in.
  App ID 는 앱 Info.plist(`GADApplicationIdentifier`)에서 SDK 가 직접 읽는다.
- `Mapping/` — SDK ↔ 도메인 변환 extension. `AdError+AdMob`(GMA 로드 에러:
  `GADErrorDomain` no-fill → `.noFill`, 그 외 → `.loadFailed`),
  `NativeAdContent+AdMob`(GMA NativeAd → DTO).
- `Support/` — 내부 협력자. `FullScreenPresentationAwaiter` (전면·보상형 공용
  present suspend — 호출별 인스턴스). 향후 공통 delegate bridge 도 여기.
- `Loaders/` — 전부 unit ID 주입, placement-generic, Core 계약 채택.
  빈 unit ID = no-op(placement 비활성).
  - `AdMobNativeAdLoader` — 단발 async 로드 (호출부가 주기를 소유)
  - `AdMobNativeAdCachedLoader` — cache-one + 유효기간 + 합류 (전면형 네이티브 표준)
  - `AdMobNativeAdPersistentLoader` — 상주 배너. `shouldShowAd` 는
    "유효한 광고 존재 && 숨김 아님" 파생값 — 별도 Bool 을 손으로 동기화하지 않는다.
  - `AdMobNativeAdRotatingLoader` — `start()`/`stop()`, 다중 캐시 + 주기 로테이션
  - `AdMobInterstitialAdLoader` / `AdMobRewardedAdLoader` — `SingleFlightCache`
    (TTL 기본 1시간 — GMA 만료 대비) + `FullScreenPresentationAwaiter`.
    보상형은 prefetch 없음(온디맨드) — AdMob show rate 를 지키는 의도된 설계.
    SSV userID 는 present 전에 붙여야 지급이 일어난다.
- `Host/` — `AdMobNativeAdHostUIView`(GMA NativeAdView 셸) +
  `AdMobNativeAdHostView`(SwiftUI 쌍). 레이아웃이 자리만 잡은 미디어/AdChoices
  컨테이너에 SDK 뷰를 삽입하고 asset 을 등록한다. 미디어 contentMode 는
  컨테이너의 값을 비춘다. `ad: nil` = 기본(no-fill) 콘텐츠 표시 — "숨김" 은
  호스트를 뷰 트리에서 제거하는 것이다.
- `Templates/` — 전면형 네이티브 기본 템플릿 (TumTumRead 레이아웃):
  `AdMobNativeAdInterstitialTemplateUIView`(카드 — GMA 무의존, 두 번째 백엔드
  도입 시 Core 이동 예정) + `AdMobNativeAdInterstitialViewController`
  + `AdMobNativeAdInterstitialView`(SwiftUI 쌍). VC 는
  `any NativeAdCachedLoading<NativeAd>` 존재형 의존 — 앱 자체 캐시 로더 주입
  가능. 스타일은 `set~` 빌더로 조정하고, 레이아웃 교체는 `NativeAdLayoutUIView`
  서브클래스 주입으로 한다 — 변형 타입을 늘리지 않는다 (뷰 컴포넌트 컨벤션).

## 설계 결정 (변경 전에 읽을 것)

- **Swift v5 모드 + 명시적 @MainActor.** GMA delegate 콜백이 Sendable 미표기라
  v6 strict 에서 소음이 크다 (AuthKitKakao 와 같은 선례). 각 로더가 @MainActor
  를 직접 단다 — 패키지 기본 격리에 기대지 않는다.
- **동시성 규칙** (Codex 교차 리뷰로 확정):
  - 로드 합류는 `SingleFlightCache`/`SingleFlightGate`(AdKit) 로만 — 자체
    continuation 조기 반환 guard 를 만들지 않는다 (합류 아님·문서 불일치의 원인).
  - present 는 호출별 `FullScreenPresentationAwaiter` 인스턴스 — 로더가 delegate
    를 겸하며 단일 continuation 슬롯을 공유하면 재진입이 슬롯을 덮어쓴다.
    표시 중 재호출은 캐시 소비 전 `alreadyPresenting` throw, 표시 직전
    `canPresent(from:)` 확인.
  - 무한 스트림/루프 Task 는 checker 를 별도 캡처하고 **iteration 안에서만**
    self 를 강참조한다 — 루프 밖 `guard let self` 는 순환 참조(deinit 불가).
    init 에서 Task 를 시작하지 않는다 (관찰은 첫 loadAd/start 에서).
  - 주기 동작은 Timer 대신 취소 가능한 `Task.sleep` 루프.
- SwiftUI 전면 광고(`AdMobNativeAdInterstitialView`)는 VC 가 스스로 dismiss 하지
  않는다 (`dismissesOnCloseTap = false`) — SwiftUI 프레젠테이션 상태는 앱
  binding 이 소유해야 어긋나지 않는다.
- 노출/클릭 트래킹 등록 순서: 에셋 뷰 구성 완료 후 마지막에 `nativeAd` 연결
  (GMA 권장). 같은 광고 재바인딩은 no-op — SwiftUI update 다중 호출 대응.
