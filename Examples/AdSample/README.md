# AdSample

AppFoundation **AdKit · AdKitAdMob** 데모 앱. Google 공식 **테스트 App ID / unit ID**
로 돌기 때문에 AdMob 콘솔 설정 없이 바로 실행된다.

데모 내용:

- **전면형 네이티브 (기본 템플릿)** — `InterstitialNativeAdTemplateUIView` +
  카운트다운 닫기 + 하단 커스텀 뷰 슬롯(`setBottomAccessoryView`, 기본은 닫기만).
  SwiftUI(`fullScreenCover`)와 UIKit(`present`) 양쪽.
- **상주 네이티브 배너 (커스텀 레이아웃)** — `NativeAdLayoutUIView` 를 직접 상속한
  `DemoBannerAdLayoutView` 를 `NativeAdHostView` 에 주입.
- **SDK 전면 광고** — `AdMobInterstitialAdLoader` preload → present.
- **보상형 광고** — 온디맨드 로드 → 즉시 표시, 시청 완료 여부 표시.
- **ATT** — `ATTAuthorization` 상태 조회·권한 요청.

## 실행

`AdSample.xcodeproj` 를 열고 시뮬레이터에서 Run — 모든 광고가 "Test Ad" 라벨을
달고 나온다.

프로젝트 구성 메모 (Xcode 에서 개발자가 만든 셸):

- **로컬 패키지 참조가 `../../../AppFoundation-ad-kit`** (feature/ad-kit 워크트리
  경로)이다. **병합 후 워크트리를 정리하면 끊어지므로**, 그 시점에 Xcode 에서
  패키지 참조를 제거하고 리포 루트를 다시 추가해야 한다 (`../..` 가 되도록 —
  Add Local 다이얼로그는 상위 폴더 선택을 거부하니 Finder 에서 폴더를 네비게이터로
  드래그). 링크 product: **AdKit, AdKitAdMob, CoreKit**.
- `Info.plist` 는 소스 동기화 폴더(`AdSample/`) **밖**에 두고 Build Settings 의
  **Info.plist File = `Info.plist`** 로만 참조한다 (리소스로 포함하면
  "Multiple commands produce Info.plist" 충돌). `Generate Info.plist File` 은
  YES — 자동 생성 키와 병합된다. 파일에는 테스트 `GADApplicationIdentifier` 와
  ATT 문구가 들어 있다.

## 실서비스 전환

테스트 ID(`DemoAdUnitID.swift`, `Info.plist`)를 자기 AdMob ID 로 교체하고,
xcconfig → Info.plist 주입 컨벤션을 쓴다. 자세한 순서는 `docs/ad/00-overview.md`.
