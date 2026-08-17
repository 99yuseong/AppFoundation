# CLAUDE.md — AppFoundation

여러 iOS 앱이 공유하는 공통 모듈 모음(Swift Package). 앱은 필요한 product 만 골라
추가한다 — 안 쓰는 외부 SDK 는 링크되지 않는다.

## 디렉토리·계층 규칙

```
Sources/{Domain}/{Layer}/{Target}
├── Core/CoreKit                    # 도메인 무관 최소 기반 (계층 없음)
├── Auth/
│   ├── Core/AuthKit                # 타입·프로토콜·오케스트레이터·로그인 버튼 (SDK 무의존)
│   ├── Providers/AuthKit{Apple,Google,Kakao}   # credential 획득 (provider SDK 소유)
│   └── Backends/
│       ├── AuthKitSupabase         # supabase-swift → 별도 타깃
│       └── AuthKitREST             # 의존성 zero → AuthKit 타깃에 포함 (폴더만 분리)
├── API/
│   ├── Core/APIKit                 # 서버 API 계약 계층 — Endpoint·APIClient (SDK 무의존)
│   └── Backends/
│       ├── APIKitSupabase          # EF/RPC/DB/Storage/Realtime 실행 (supabase-swift 소유)
│       └── APIKitREST              # URLSession 실행 — 의존성 zero → APIKit 타깃에 포함
├── Image/
│   └── Core/ImageKit               # 다운샘플링·이미지 캐시 파이프라인·RemoteImage 뷰 쌍 (SDK 무의존)
├── Experiment/
│   ├── Core/ExperimentKit          # 실험·원격 설정 계약 — ExperimentClient·ExperimentKey (SDK 무의존)
│   └── Backends/ExperimentKitFirebase  # Firebase Remote Config 어댑터 (firebase-ios-sdk 소유)
└── Ad/
    ├── Core/AdKit                  # 광고 계약 — 전면·보상형 계약, 네이티브 레이아웃 베이스, ATT, Mock (SDK 무의존)
    └── Backends/AdKitAdMob         # Google Mobile Ads 실행 — 로더·호스트·전면형 네이티브 기본 템플릿 (GMA 소유)
```

- **폴더 = 계층, 타깃 = SDK 경계.** 이 둘은 1:1 이 아니다. 계층 구분은 디렉토리로
  표현하고, **타깃은 외부 SDK 의존이 갈리는 지점에서만** 쪼갠다 — 타깃이 늘수록
  빌드 그래프가 무거워지므로 의존성 없는 계층끼리는 한 타깃으로 묶는다.
  현재 `AuthKit` 타깃 = `Core/AuthKit` + `Backends/AuthKitREST`,
  `APIKit` 타깃 = `Core/APIKit` + `Backends/APIKitREST`
  (Package.swift 에서 `path` 를 도메인 루트로 올리고 SDK 폴더만 `exclude`).
  → 새 계층·폴더를 추가할 때 **자동으로 새 타깃을 만들지 말 것.** 외부 SDK 를
    물지 않으면 기존 타깃의 `path` 안에 폴더만 추가한다.
- **의존 방향은 안쪽으로만**: Providers/Backends → Core(AuthKit/APIKit) → CoreKit.
  Provider 와 Backend 는 서로 import 하지 않는다.
- **product 분리 원칙**: 외부 SDK 의존이 있는 타겟은 반드시 별도 product.
  provider 는 전부 `AuthKit{Provider}` 대칭 규칙 (외부 SDK 가 없는 Apple 도 동일 —
  provider 는 앱이 골라 링크하는 단위라 SDK 유무와 무관하게 대칭을 유지한다).
- 새 도메인(Purchase/Ads/Analytics/Push)은 같은 구조로 추가한다.
- 각 타겟 최상단의 CLAUDE.md 가 그 모듈의 책임·경계를 정의한다 — 수정 전에 읽는다.

## 개방형 provider 원칙

- `SocialProvider` 는 닫힌 enum 이 아니라 String 기반 struct — 앱이 kit 수정 없이
  자체 provider 를 정의한다.
- 버튼·서비스에 provider switch 를 새로 넣지 않는다. 디자인은 `AuthProvider.branding`
  (생성자 주입), 노출 목록은 `AuthService.loginOptions`(주입 순서 = 노출 순서)가
  단일 진실 소스다.
- API 도메인도 동일: `EndpointTransport`/`HTTPMethod` 는 개방형 String struct.
  `APIClient` 는 `request`/`stream` 단일 진입 — verb 별 메서드를 추가하지 않는다
  (verb·페이로드는 `Endpoint.method`/`.task` 선언 메타데이터, 강제 없음).

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
- **테스트는 핵심 로직만.** 상수를 재서술하는 테스트는 만들지 않는다.
  (예외: `.asset(_:)` 처럼 실패해도 컴파일이 통과하고 조용히 폴백하는 지점)

## CI (GitHub Actions)

PR 마다 두 워크플로우가 돈다 — 둘 다 Claude 기반이고 ubuntu 러너를 쓴다
(리뷰·문서 대조는 Xcode 가 필요 없고, private repo 의 macOS 러너는 10배 과금).

- `.github/workflows/claude-code-review.yml` — 변경분 코드 리뷰
- `.github/workflows/docs-freshness.yml` — 변경분 대비 낡은 문서 탐지

**필요 설정** (둘 다 repo secret):
- `CLAUDE_CODE_OAUTH_TOKEN` — 구독(Max/Pro) 기반 인증. 로컬에서
  `claude setup-token` 으로 발급한다. API 키를 따로 발급받지 않아도 된다.
- `GITHUB_TOKEN` 은 워크플로우가 자동 제공하지만 **명시 전달이 필요**하다 —
  안 주면 액션이 Claude GitHub App 설치를 요구하며 401 로 실패한다.

빌드·테스트는 CI 에서 돌리지 않는다 — 병합 전 로컬 게이트(위 3개 커맨드)로 확인한다.
문서 정합성 검사를 규칙 스크립트로 만들지 마라: product 목록·심볼을 하드코딩한
검사기는 그 자체가 최신화 대상이 된다(전례가 있어 폐기했다).

## 버전/배포

- 전역 semver 태그 (모듈별 태그 없음). breaking 은 0.x 동안 수용하되 CHANGELOG 에 명시.
- 커밋 prefix: `Feat:` `Fix:` `Refactor:` `Docs:` `Test:`. 커밋·푸시는 사용자 지시 시에만.

## 문서

- 설정 순서·서버 계약: `docs/auth/00~08` (00 이 진입점)
- API 도메인 개념·비용 원칙·서버 확장 스토리: `docs/api/00-overview.md`
- 신규 앱 통합 안내 스킬: `.claude/skills/auth-setup`
