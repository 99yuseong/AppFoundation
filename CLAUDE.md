# CLAUDE.md — AppFoundation

여러 iOS 앱이 공유하는 공통 모듈 모음(Swift Package). 앱은 필요한 product 만 골라
추가한다 — 안 쓰는 외부 SDK 는 링크되지 않는다.

## 디렉토리·계층 규칙

```
Sources/{Domain}/{Layer}/{Target}
├── Core/CoreKit                    # 도메인 무관 최소 기반 (계층 없음)
└── Auth/
    ├── Core/AuthKit                # 타입·프로토콜·오케스트레이터·로그인 버튼 (SDK 무의존)
    ├── Providers/AuthKit{Apple,Google,Kakao}   # credential 획득 (provider SDK 소유)
    └── Backends/AuthKit{Supabase,REST}         # credential ↔ 세션 교환
```

- **의존 방향은 안쪽으로만**: Providers/Backends → Core(AuthKit) → CoreKit.
  Provider 와 Backend 는 서로 import 하지 않는다.
- **product 분리 원칙**: 외부 SDK 의존이 있는 타겟은 반드시 별도 product.
  provider 는 전부 `AuthKit{Provider}` 대칭 규칙 (외부 SDK 가 없는 Apple 도 동일).
- 새 도메인(Purchase/Ads/Analytics/Push)은 같은 구조로 추가한다.
- 각 타겟 최상단의 CLAUDE.md 가 그 모듈의 책임·경계를 정의한다 — 수정 전에 읽는다.

## 개방형 provider 원칙

- `SocialProvider` 는 닫힌 enum 이 아니라 String 기반 struct — 앱이 kit 수정 없이
  자체 provider 를 정의한다.
- 버튼·서비스에 provider switch 를 새로 넣지 않는다. 디자인은 `AuthProvider.branding`
  (생성자 주입), 노출 목록은 `AuthService.loginOptions`(주입 순서 = 노출 순서)가
  단일 진실 소스다.

## 뷰 컴포넌트 컨벤션 (set~ 빌더)

- 설정값은 내부 변수로 저장하고 `set~` 접두 빌더 모디파이어로 수정한다.
  SwiftUI 는 값 복사 후 Self 반환, UIKit 은 `@discardableResult` + Self 반환.
- SwiftUI·UIKit 양쪽을 항상 함께 제공한다 (`SocialLoginButton` ↔ `SocialLoginUIButton`).
- 변형은 타입을 늘리지 않고 값 주입으로 흡수한다 (option 주입 단일 컴포넌트).

## 빌드/테스트

```bash
xcodebuild build -scheme AppFoundation-Package -destination 'generic/platform=iOS Simulator'
xcodebuild test -scheme AppFoundation-Package -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild build -project Examples/AuthSample/AuthSample.xcodeproj -scheme AuthSample -destination 'generic/platform=iOS Simulator'
```

- swift-tools 6.2 / iOS 17+ / Swift 6 모드 (AuthKitKakao 만 v5 — KakaoSDK Sendable 미표기)
- swift-testing 사용. HTTP 는 URLProtocol 스텁 + `.serialized` suite 패턴.

## 버전/배포

- 전역 semver 태그 (모듈별 태그 없음). breaking 은 0.x 동안 수용하되 CHANGELOG 에 명시.
- 커밋 prefix: `Feat:` `Fix:` `Refactor:` `Docs:` `Test:`. 커밋·푸시는 사용자 지시 시에만.

## 문서

- 설정 순서·서버 계약: `docs/auth/00~08` (00 이 진입점)
- 신규 앱 통합 안내 스킬: `.claude/skills/auth-setup`
