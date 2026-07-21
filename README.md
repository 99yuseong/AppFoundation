# AppFoundation

여러 iOS 앱이 공유하는 공통 모듈 모음 (Swift Package).
앱 타겟에는 **필요한 product 만 골라 추가**한다 — 안 쓰는 외부 SDK 는 링크되지 않는다.

## Products

| product | 내용 | 외부 의존성 | 상태 |
|---|---|---|---|
| `CoreKit` | Info.plist 설정 로더(`ConfigValues`), `TopMostPresenter` | 없음 | ✅ |
| `AuthKit` | Auth 코어(타입·프로토콜·`DefaultAuthService`·Mock) + **로그인 버튼**(SwiftUI/UIKit, ko·en·ja) | 없음 | ✅ |
| `AuthKitApple` | Apple provider | 없음 (AuthenticationServices) | ✅ |
| `AuthKitSupabase` | Supabase 백엔드 (`SupabaseAuthBackend`) | supabase-swift | ✅ |
| `AuthKitGoogle` | Google provider | GoogleSignIn-iOS | ✅ |
| `AuthKitKakao` | Kakao provider (네이티브, OIDC) | kakao-ios-sdk | ✅ |
| `PurchaseKit` / `AdsKit` / `AnalyticsKit` / Push | — | — | 예정 |

## 빠른 시작 (Auth)

1. **콘솔 설정**: [docs/auth/00-overview.md](docs/auth/00-overview.md) 의 체크리스트를
   따라 Apple / Kakao / Google / Supabase 를 세팅한다.
2. **SPM 추가**: `git@github.com:{계정}/AppFoundation.git` →
   `AuthKit` + `AuthKitSupabase` + 사용하는 provider product
   (`AuthKitApple` / `AuthKitGoogle` / `AuthKitKakao` — 대칭 규칙).
3. **조립**:

```swift
let authService: any AuthService = DefaultAuthService(
    backend: SupabaseAuthBackend(
        client: client,   // 앱 전역 SupabaseClient 하나를 주입
        configuration: .init(supabaseURL: supabaseURL, apiKey: supabaseKey)
    ),
    providers: [AppleAuthProvider(), KakaoAuthProvider()]
)

let result = try await authService.signIn(with: .apple, presenter: nil)
```

로그인 버튼 (브랜드 스펙 + ko/en/ja, SwiftUI/UIKit):

```swift
SocialLoginButton { signInKakao() }
    .setProvider(.kakao)
    .setCornerRadius(16)
    .setIsLoading($isLoading)
```

상세: [docs/auth/05-app-integration.md](docs/auth/05-app-integration.md) ·
동작 데모: [Examples/AuthSample](Examples/AuthSample/README.md)

## Claude 스킬로 세팅 안내 받기

이 repo 에는 신규 앱 통합을 안내하는 Claude Code 스킬이 포함돼 있다.
앱 프로젝트에서:

```bash
ln -s {AppFoundation 클론 경로}/.claude/skills/auth-setup .claude/skills/auth-setup
```

이후 `/auth-setup` 을 실행하면 provider 선택부터 콘솔 설정·코드 조립까지 순서대로 안내한다.

## 회원탈퇴 (표준: 재인증형 하이브리드)

`supabase/functions/account-withdraw` 템플릿을 배포하면 Apple/Google revoke +
Kakao unlink + 계정 삭제가 한 번에 처리된다.
상세: [docs/auth/06-edge-functions.md](docs/auth/06-edge-functions.md)

## 개발

```bash
# 빌드
xcodebuild build -scheme AppFoundation-Package -destination 'generic/platform=iOS Simulator'
# 테스트
xcodebuild test -scheme AppFoundation-Package -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

- swift-tools 6.2 / iOS 17+ / Swift 6 모드 (AuthKitKakao 만 v5 — KakaoSDK 호환)
- 로컬 개발 시 앱 workspace 에 클론 폴더를 드래그하면 원격 패키지를 오버라이드한다

## 버전

전역 semver 태그 (`0.1.0` …). 멀티 모듈 단일 repo 라 모듈별 태그는 쓰지 않는다.
변경 이력: [CHANGELOG.md](CHANGELOG.md)
