# AdSample

AppFoundation **AdKit · AdKitAdMob** 데모 앱. Google 공식 **테스트 App ID / unit ID**
로 돌기 때문에 AdMob 콘솔 설정 없이 바로 실행된다.

데모 내용:

- **전면형 네이티브 (기본 템플릿)** — `InterstitialNativeAdTemplateUIView` +
  카운트다운 닫기 + promo CTA. SwiftUI(`fullScreenCover`)와 UIKit(`present`) 양쪽.
- **상주 네이티브 배너 (커스텀 레이아웃)** — `NativeAdLayoutUIView` 를 직접 상속한
  `DemoBannerAdLayoutView` 를 `NativeAdHostView` 에 주입.
- **SDK 전면 광고** — `AdMobInterstitialAdLoader` preload → present.
- **보상형 광고** — 온디맨드 로드 → 즉시 표시, 시청 완료 여부 표시.
- **ATT** — `ATTAuthorization` 상태 조회·권한 요청.

## 프로젝트 셋업 (최초 1회 — Xcode 에서)

`.xcodeproj` 는 커밋돼 있지 않다(Xcode 시스템 파일은 손으로 만들지 않는 방침).
소스(`AdSample/`)와 `Info.plist` 는 준비돼 있으니 셸만 만들면 된다:

1. Xcode → File → New → Project → **iOS App**.
   Product Name `AdSample`, Interface **SwiftUI**. 저장 위치는 **임시 폴더**(Desktop 등).
2. Finder 에서 임시 프로젝트의 **`AdSample.xcodeproj` 만** 이 폴더
   (`Examples/AdSample/`)로 이동한다. 임시 폴더의 나머지(자동 생성 소스)는 삭제.
   → Xcode 16 의 폴더 동기화 그룹이라, 열면 여기 있는 `AdSample/` 소스가 자동 인식된다.
3. 프로젝트를 열고 로컬 패키지 연결: 프로젝트 설정 → Package Dependencies →
   **Add Local…** → 리포 루트(`AppFoundation`) 선택 → 타깃에 **AdKit, AdKitAdMob,
   CoreKit** 3개 링크.
4. 타깃 Build Settings → **Info.plist File** = `Info.plist`
   (준비된 파일 — `GADApplicationIdentifier` 테스트 App ID + ATT 문구 포함).
   `Generate Info.plist File` 은 YES 유지 (키가 병합된다).
5. 타깃 **Minimum Deployments** = iOS 17.0.

이후 시뮬레이터에서 Run — 모든 광고가 "Test Ad" 라벨을 달고 나온다.

## 실서비스 전환

테스트 ID(`DemoAdUnitID.swift`, `Info.plist`)를 자기 AdMob ID 로 교체하고,
xcconfig → Info.plist 주입 컨벤션을 쓴다. 자세한 순서는 `docs/ad/00-overview.md`.
