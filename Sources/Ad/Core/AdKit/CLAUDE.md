# AdKit

광고 도메인 계약 계층. 외부 SDK 무의존 (AppTrackingTransparency 는 시스템
프레임워크라 허용).

## 폴더 구조 (서브도메인 단위 — 1 타입 1 파일)

```
Loading/    로더 수명주기 계약 6종 (계열 공통 설계 주석은 NativeAdLoading.swift)
Layout/     백엔드 중립 네이티브 레이아웃 — NativeAdLayoutUIView + NativeAdContent
Condition/  광고 표시 조건 게이트 — AdConditionChecker + AlwaysAllow 기본 구현
ATT/        App Tracking Transparency — 진입점 + 상태 enum 2종
Error/      AdError
Support/    package 내부 동시성 프리미티브 — SingleFlightCache/Gate
Mock/       프리뷰·테스트용 mock 3종
```

기술 역할(Entity/Interface/Service)이 아니라 **서브도메인으로 묶는다** — 응집된
쌍(레이아웃 뷰↔DTO, 체커↔기본 구현, ATT 진입점↔상태)이 같은 폴더에 있어야
한다. 새 타입은 반드시 자기 파일로 만든다 (1 타입 1 파일).

## 공개 API

- `InterstitialAdLoading` / `RewardedAdLoading` — 전면·보상형 백엔드 계약.
  보상형 `present` 의 반환값은 시청 완료 여부일 뿐, 지급은 서버(SSV)가 결정한다.
- `NativeAdLoading` / `NativeAdCachedLoading` / `NativeAdPersistentLoading` /
  `NativeAdRotatingLoading` — 네이티브 로더 **수명주기 계약**. associatedtype
  `Ad` 가 SDK 광고 타입을 추상화한다 (전 요구 @MainActor 격리라 `Ad: Sendable`
  불요). 주의: `any … Loading<Ad>` 존재형은 `@ObservedObject` 불가 — 게시 값을
  관찰하는 뷰는 제네릭으로 받는다.
- `NativeAdLayoutUIView` — 네이티브 광고 레이아웃 베이스 클래스. 앱이 상속해
  자체 디자인을 만들고 백엔드 호스트에 주입한다. 미디어·AdChoices 는 자리
  (컨테이너 UIView)만 잡는다 — SDK 뷰 삽입은 백엔드 호스트 소유.
- `NativeAdContent` — SDK 무의존 광고 데이터 DTO. SDK → DTO 변환은 각 백엔드가
  extension 으로 소유한다.
- `AdConditionChecker` — 구독(광고 제거)·킬스위치 게이트 protocol (+`AlwaysAllow…`).
  상주형 로더에 주입한다 — 온디맨드(전면·보상형)는 앱 파사드에서 게이트.
- `ATTAuthorization` — ATT 상태 조회·프롬프트. `status`(행동용, restricted→denied
  접음) 와 `rawStatus`(분석용, 안 접음) 를 구분한다.
- `SingleFlightCache` / `SingleFlightGate` — **`package` 접근** (앱 비노출,
  백엔드 구현 공유용). 캐시는 TTL 을 init 정책으로 받고 만료를 isReady/take
  모든 경계에서 검사한다. 둘 다 실패(throw)를 합류자 전원에게 동일 전파 —
  SDK 없이 테스트하기 위해 여기 있다 (MainActor 격리).
- `AdError` — `.noFill`(정상적 미채움) / `.notReady` / `.alreadyPresenting`
  (캐시 미소비) / `.loadFailed` / `.presentationFailed`.
- `Mock/` — `MockInterstitialAdLoader`·`MockRewardedAdLoader`·
  `MockNativeAdCachedLoader<Ad>` (프리뷰·앱 파사드 테스트용. 네이티브 렌더링은
  SDK 뷰가 필요해 mock 범위 밖).

## 설계 결정 (변경 전에 읽을 것)

- **placement 를 kit 에 새기지 않는다.** 로더는 unit ID(String) 주입을 받는
  placement-generic 단위다. placement 별 파사드(예: "매칭 전면", "티켓 보상")는
  앱의 로컬 AdKit 패키지가 조립한다 — 개방형 provider 원칙과 동일.
- **네이티브 로더 수명주기 계약은 associatedtype `Ad` 로 Core 가 소유한다.**
  **렌더링(호스트) 계약은 여전히 Core 에 없다** — SDK 뷰 타입이 필수라 SDK-free
  계약이 성립하지 않는다. Core 는 레이아웃 계약
  (`NativeAdLayoutUIView`·`NativeAdContent`)과 수명주기 계약만 소유한다.
- 계약 접미사 규칙: 백엔드 클래스 `~Loader` ↔ Core 계약 `~Loading` 쌍.
- 레이아웃 서브클래스는 UIKit + AdKit 만 import 한다 — 광고 SDK 타입이 새면
  이 경계가 무너진 것이다.
