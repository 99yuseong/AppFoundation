# AdKit

광고 도메인 계약 계층. 외부 SDK 무의존 (AppTrackingTransparency 는 시스템
프레임워크라 허용).

## 공개 API

- `InterstitialAdControlling` / `RewardedAdControlling` — 전면·보상형 백엔드 계약.
  보상형 `present` 의 반환값은 시청 완료 여부일 뿐, 지급은 서버(SSV)가 결정한다.
- `NativeAdLayoutUIView` — 네이티브 광고 레이아웃 베이스 클래스. 앱이 상속해
  자체 디자인을 만들고 백엔드 호스트에 주입한다. 미디어·AdChoices 는 자리
  (컨테이너 UIView)만 잡는다 — SDK 뷰 삽입은 백엔드 호스트 소유.
- `NativeAdContent` — SDK 무의존 광고 데이터 DTO. SDK → DTO 변환은 각 백엔드가
  extension 으로 소유한다.
- `AdConditionChecker` — 구독(광고 제거)·킬스위치 게이트 protocol (+`AlwaysAllow…`).
- `ATTAuthorization` — ATT 상태 조회·프롬프트. `status`(행동용, restricted→denied
  접음) 와 `rawStatus`(분석용, 안 접음) 를 구분한다.
- `SingleFlightCache` — load-once 캐시 + in-flight 합류. 백엔드 로더의 합류
  로직을 SDK 없이 테스트하기 위해 여기 있다 (MainActor 격리).
- `AdError`, `Mocks/`(MockInterstitialAd·MockRewardedAd — 프리뷰·테스트용).

## 설계 결정 (변경 전에 읽을 것)

- **placement 를 kit 에 새기지 않는다.** 로더는 unit ID(String) 주입을 받는
  placement-generic 단위다. placement 별 파사드(예: "매칭 전면", "티켓 보상")는
  앱의 로컬 AdKit 패키지가 조립한다 — 개방형 provider 원칙과 동일.
- **네이티브 광고 로더 계약은 Core 에 없다.** SDK 광고 객체를 뷰에 바인딩해야
  해서 SDK-free 계약이 성립하지 않는다. Core 는 레이아웃 계약
  (`NativeAdLayoutUIView`·`NativeAdContent`)만 소유해 레이아웃이 백엔드 간
  재사용되게 한다.
- 레이아웃 서브클래스는 UIKit + AdKit 만 import 한다 — 광고 SDK 타입이 새면
  이 경계가 무너진 것이다.
