# AdKitAdMob

Google Mobile Ads(AdMob) 실행 계층 — GoogleMobileAds SDK 는 이 타깃만 소유한다.
TumTumRead AdFeature + Doran AdKit 의 로더·뷰를 placement-generic 으로 일반화해
이식했다.

## 구성

- `AdMobConfigurator` — SDK 시작·테스트 기기 등록·오디오 세션 관리 opt-in.
  App ID 는 앱 Info.plist(`GADApplicationIdentifier`)에서 SDK 가 직접 읽는다.
- `Loaders/` — 전부 unit ID 주입, placement-generic. 빈 unit ID = no-op(placement 비활성).
  - `AdMobNativeAdLoader` — 단발 async 로드 (호출부가 주기를 소유)
  - `AdMobCachedNativeAdLoader` — cache-one + 유효기간 + 합류 (전면형 네이티브 표준)
  - `AdMobPersistentNativeAdLoader` — 상주 배너, `AdConditionChecker` 반응 show/hide
  - `AdMobRotatingNativeAdLoader` — 다중 캐시 + 주기 로테이션
  - `AdMobInterstitialAdLoader` / `AdMobRewardedAdLoader` — Core 계약 채택.
    보상형은 prefetch 없음(온디맨드) — AdMob show rate 를 지키는 의도된 설계.
    SSV userID 는 present 전에 붙여야 지급이 일어난다.
- `Host/` — `NativeAdHostUIView`(GMA NativeAdView 셸) + `NativeAdHostView`(SwiftUI 쌍).
  레이아웃이 자리만 잡은 미디어/AdChoices 컨테이너에 SDK 뷰를 삽입하고 asset 을
  등록한다. 미디어 contentMode 는 컨테이너의 값을 비춘다.
- `Templates/` — 전면형 네이티브 기본 템플릿 (TumTumRead 레이아웃):
  `InterstitialNativeAdTemplateUIView`(카드) + `NativeAdInterstitialViewController`
  + `NativeAdInterstitialView`(SwiftUI 쌍). 스타일은 `set~` 빌더로 조정하고,
  레이아웃 교체는 `NativeAdLayoutUIView` 서브클래스 주입으로 한다 — 변형 타입을
  늘리지 않는다 (뷰 컴포넌트 컨벤션).

## 설계 결정 (변경 전에 읽을 것)

- **Swift v5 모드 + 명시적 @MainActor.** GMA delegate 콜백이 Sendable 미표기라
  v6 strict 에서 소음이 크다 (AuthKitKakao 와 같은 선례). 각 로더가 @MainActor
  를 직접 단다 — 패키지 기본 격리에 기대지 않는다.
- SwiftUI 전면 광고(`NativeAdInterstitialView`)는 VC 가 스스로 dismiss 하지
  않는다 (`dismissesOnCloseTap = false`) — SwiftUI 프레젠테이션 상태는 앱
  binding 이 소유해야 어긋나지 않는다.
- 노출/클릭 트래킹 등록 순서: 에셋 뷰 구성 완료 후 마지막에 `nativeAd` 연결
  (GMA 권장). 같은 광고 재바인딩은 no-op — SwiftUI update 다중 호출 대응.
- 전면·보상형 present 는 dismiss 시점까지 suspend 하는 continuation 패턴.
  표시 실패는 delegate 가 에러를 저장했다가 다시 던진다 — 조용한 조기 종료와
  구분된다.
