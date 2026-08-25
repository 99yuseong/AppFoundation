# AppFoundation

여러 iOS 앱이 공유하는 공통 모듈 모음입니다. Swift Package 하나로 관리하고,
각 앱은 필요한 product만 골라 링크합니다 — 쓰지 않는 외부 SDK는 앱에 포함되지 않습니다.

## 설계 원칙

- **Core / Provider / Backend 계층.** Core는 외부 SDK 없이 계약(프로토콜·타입)만 정의하고,
  외부 SDK는 Backend product에 격리합니다. 앱은 같은 계약 위에서 백엔드만 갈아끼울 수 있습니다.
- **product는 SDK 경계에서만 분리.** 계층 구분은 디렉토리로 표현하고, 타깃은 외부 의존이
  갈리는 지점에서만 쪼개 빌드 그래프를 가볍게 유지합니다.
- **개방형 확장.** provider·transport 같은 축은 닫힌 enum이 아니라 String 기반 타입이라,
  앱이 패키지를 수정하지 않고 자체 구현을 추가할 수 있습니다.

## 모듈

| Product | 설명 | 외부 SDK |
|---|---|---|
| `CoreKit` | 공통 기반 — Info.plist 설정 로더, 메모리/디스크 캐시, 최상단 프리젠터 | – |
| `AuthKit` | 소셜 로그인 코어 — 서비스 오케스트레이터, 로그인 버튼(SwiftUI/UIKit, ko·en·ja), REST 백엔드 | – |
| `AuthKitApple` | Apple 로그인 provider | – |
| `AuthKitGoogle` | Google 로그인 provider | GoogleSignIn |
| `AuthKitKakao` | Kakao 로그인 provider (네이티브, OIDC) | KakaoSDK |
| `AuthKitSupabase` | Supabase 세션 교환 백엔드 | supabase-swift |
| `APIKit` | 서버 API 계약 — `Endpoint` 선언, `APIClient`, URLSession·R2 스토리지 실행 포함 | – |
| `APIKitSupabase` | Edge Function·RPC·DB·Storage·Realtime 실행 | supabase-swift |
| `ImageKit` | 원격 이미지 파이프라인 — 다운샘플링, 캐시, `RemoteImage` 뷰 | – |
| `ExperimentKit` | A/B 실험·원격 설정 계약 | – |
| `ExperimentKitFirebase` | Firebase Remote Config 어댑터 | firebase-ios-sdk |
| `AdKit` | 광고 계약 — 전면·보상형·네이티브 로더, 레이아웃 베이스, ATT | – |
| `AdKitAdMob` | AdMob 실행 — 로더, 네이티브 광고 호스트·기본 템플릿 | GoogleMobileAds |
| `PurchaseKit` | 인앱결제 — 서비스 계약, SDK-free 모델, StoreKit 2 구현 포함 | – |
| `PurchaseKitRevenueCat` | RevenueCat 백엔드 | purchases-ios |

## 빠른 시작 — 소셜 로그인

SPM으로 `AuthKit` + 백엔드 + 사용할 provider product를 추가하고 조립합니다.

```swift
let authService: any AuthService = DefaultAuthService(
    backend: SupabaseAuthBackend(
        client: client,
        configuration: .init(supabaseURL: supabaseURL, apiKey: supabaseKey)
    ),
    providers: [AppleAuthProvider(), KakaoAuthProvider()]  // 주입 순서 = 버튼 노출 순서
)

let result = try await authService.signIn(with: .apple, presenter: nil)
```

로그인 버튼은 조립 시 등록한 provider만 노출합니다.

```swift
SocialLoginButtonStack(options: authService.loginOptions) { provider in
    signIn(provider)
}
.setCornerRadius(16)
.setIsLoading($isLoading)
```

콘솔 설정부터 회원탈퇴 처리까지의 전체 순서는 [docs/auth](docs/auth/00-overview.md)에,
동작하는 데모는 [Examples/AuthSample](Examples/AuthSample/README.md)에 있습니다.

## 개발

```bash
# 빌드
xcodebuild build -scheme AppFoundation-Package -destination 'generic/platform=iOS Simulator'
# 테스트
xcodebuild test -scheme AppFoundation-Package -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

- swift-tools 6.2 / iOS 17+ / Swift 6 모드 (SDK 호환 문제로 `AuthKitKakao`·`AdKitAdMob`만 v5)
- 로컬 개발 시 앱 workspace에 클론 폴더를 드래그하면 원격 패키지를 오버라이드합니다
- 버전은 전역 semver 태그 하나로 관리합니다 — [CHANGELOG.md](CHANGELOG.md)

## 문서

| | |
|---|---|
| [docs/auth](docs/auth/00-overview.md) | 콘솔 설정 체크리스트, 앱 통합, 회원탈퇴 Edge Function, 커스텀 백엔드 |
| [docs/api](docs/api/00-overview.md) | API 도메인 개념과 서버 확장 스토리 |
| [docs/api/01-storage.md](docs/api/01-storage.md) | Storage 계약, R2 전환 체크리스트, 계정 전략 |
| [docs/ad](docs/ad/00-overview.md) | 광고 도메인 구조와 AdMob 통합 |
| [docs/purchase](docs/purchase/00-overview.md) | 결제 백엔드 선택 기준과 앱 마이그레이션 |
| [Examples](Examples) | AuthSample · AdSample 데모 앱 |

신규 앱에 로그인을 붙일 때는 동봉된 Claude Code 스킬(`.claude/skills/auth-setup`)을
앱 프로젝트에 심볼릭 링크하고 `/auth-setup`을 실행하면 설정 순서를 안내받을 수 있습니다.
