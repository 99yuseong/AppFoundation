# Ad 도메인 — 개요·통합 가이드

TumTumRead(AdFeature)와 Doran(AdKit)의 광고 모듈을 통합·일반화한 도메인.
계약은 `AdKit`(SDK 무의존), 실행은 `AdKitAdMob`(GoogleMobileAds 소유)에 있다.

## 구조 원칙

- **placement 는 앱 소유.** kit 의 로더는 unit ID(String)를 주입받는
  placement-generic 단위다. "매칭 전면", "하단 배너" 같은 placement 파사드는
  각 앱의 로컬 AdKit 패키지(DoranAdKit·TumTumAdKit)가 조립한다.
- **레이아웃은 백엔드 중립.** 앱은 `NativeAdLayoutUIView`(AdKit)를 상속해
  자체 디자인을 만든다 — UIKit + AdKit 만 import. 미디어·AdChoices 는 자리만
  잡고, SDK 뷰 삽입·트래킹 등록은 백엔드 호스트(`NativeAdHostUIView`)가 한다.
  같은 레이아웃이 향후 다른 백엔드(AppLovin 등)에서도 재사용된다.
- **백엔드 확장**: AppLovin 등을 추가하려면 `Ad/Backends/AdKitAppLovin` 타깃을
  만들고 (1) 전면·보상형은 `InterstitialAdControlling`/`RewardedAdControlling`
  채택, (2) 네이티브는 자체 호스트 뷰가 `NativeAdLayoutUIView` 의 컨테이너에
  자기 SDK 뷰를 삽입 + `NativeAdContent` 변환 extension 제공.

## 앱 통합 순서 (AdMob)

1. **App ID** — 앱 Info.plist 에 `GADApplicationIdentifier` 를 설정한다
   (xcconfig 변수 주입 권장: `GADApplicationIdentifier = $(ADMOB_APP_ID)`).
   Xcode 시스템 파일이므로 개발자가 직접 처리한다.
2. **unit ID** — placement 별 unit ID 도 xcconfig → Info.plist 커스텀 키로
   주입하고 앱에서 읽는다 (CoreKit `ConfigValues` 사용 가능). 빈 unit ID 는
   로더가 no-op 처리하므로 "빈 값 = placement 비활성" 컨벤션이 성립한다.
3. **SDK 시작** — 앱 시작 시 1회:
   ```swift
   await AdMobConfigurator(testDeviceIdentifiers: testIDs).configure()
   ```
   테스트 기기 목록은 앱이 `#if DEBUG || DEV` 로 거른다 (패키지는 앱의 빌드
   조건을 못 본다). 오디오를 직접 다루는 앱은
   `managesAudioSessionForVideoAds: true` (Doran 선례 — 영상 광고의
   AVAudioSession 강탈 방지).
4. **ATT** — 온보딩에서 `await ATTAuthorization.request()` (AdKit).
   SDK 시작과 순서 무관. 분석용 상태는 `ATTAuthorization.rawStatus`.
5. **광고 제거 게이트** — 구독 등이 있으면 `AdConditionChecker` 구현체를
   로더에 주입한다 (기본은 `AlwaysAllowAdConditionChecker`).

## 광고 타입별 사용

| 타입 | 로더 | 패턴 |
|---|---|---|
| 네이티브 (단발) | `AdMobNativeAdLoader` | 호출부가 주기 소유, 틱마다 1개 로드 |
| 네이티브 (전면형) | `AdMobCachedNativeAdLoader` | cache-one + 유효기간 + 합류. 미리 `loadAd()` → 노출 시 소비 |
| 네이티브 (상주 배너) | `AdMobPersistentNativeAdLoader` | `@Published currentAd`/`shouldShowAd` 관찰 |
| 네이티브 (로테이션) | `AdMobRotatingNativeAdLoader` | 다중 캐시 + 주기 교체 |
| 전면 | `AdMobInterstitialAdLoader` | preload → `present(from:)`, dismiss 까지 suspend |
| 보상형 | `AdMobRewardedAdLoader` | **온디맨드** (show rate 보호), SSV userID 는 present 시 전달 |

### 전면형 네이티브 (기본 템플릿)

```swift
let loader = AdMobCachedNativeAdLoader(adUnitId: unitID)
await loader.loadAd()   // 노출 전에 미리

// UIKit
let vc = NativeAdInterstitialViewController(adLoader: loader)
    .setCloseButtonUnlockInterval(5)
    .setBottomAccessoryView(mySubscribeButton)  // 선택 — 닫기 버튼 위 커스텀 뷰. 없으면 닫기만
presenter.present(vc, animated: true)   // presenter 가 없으면 TopMostPresenter.topViewController()

// SwiftUI
.fullScreenCover(isPresented: $isShowingAd) {
    NativeAdInterstitialView(adLoader: loader)
        .setOnClose { isShowingAd = false }
        .ignoresSafeArea()
}
```

- 기본 카드 디자인은 `InterstitialNativeAdTemplateUIView` (TumTumRead 레이아웃).
  스타일은 `set~` 빌더(색·폰트·radius·미디어 비율), 레이아웃 전체 교체는
  `setAdContentView(_:)` 에 `NativeAdLayoutUIView` 서브클래스 주입.

### 커스텀 네이티브 레이아웃

```swift
final class MyAdView: NativeAdLayoutUIView {          // import AdKit (GMA 불필요)
    override func setupLayout() { ... }               // 서브뷰·제약
    override var adHeadlineLabel: UILabel? { ... }    // 트래킹 등록할 asset 만
    override var adMediaContainerView: UIView? { ... } // 자리만 — SDK 뷰는 호스트가 삽입
    override func configure(with content: NativeAdContent) { ... }
    override func configureDefaultContent() { ... }   // no-fill 폴백
}

// 표시: UIKit 은 NativeAdHostUIView(contentView:), SwiftUI 는
NativeAdHostView(ad: loader.currentAd) { MyAdView() }
```

## 앱 이관 메모

- **Doran**: 로컬 `Packages/AdKit` → `DoranAdKit` 으로 리네임 후 AppFoundation
  `AdKit`·`AdKitAdMob` 의존. `AdService` 파사드·Matching 전용 스타일·QA 헬퍼만
  잔류. `ATTAuthorization`·`AdConditionChecker`·전면·보상형 로더는 그대로 대체.
- **TumTumRead**: `AdFeature` → 로컬 `TumTumAdKit` 패키지화, GMA 12→13
  마이그레이션 후 채택. `BaseNativeAdUIView` 서브클래스들은
  `NativeAdLayoutUIView` 로 부모만 교체 (미디어/AdChoices 는 전용 래퍼 뷰 대신
  일반 UIView 컨테이너로).
- UMP(동의 관리)는 현재 범위 밖 — 필요 시 AdKitAdMob 에 추가한다.
