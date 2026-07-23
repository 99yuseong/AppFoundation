# AppFoundation

여러 iOS 앱이 공유하는 공통 모듈 모음 (Swift Package).
앱 타겟에는 **필요한 product 만 골라 추가**한다 — 안 쓰는 외부 SDK 는 링크되지 않는다.

## Products

Auth 는 3계층 — **Core**(타입·오케스트레이터·버튼) / **Providers**(credential 획득) /
**Backends**(세션 교환) — 로 나뉘어 어느 백엔드와도 조합된다. API 도메인도 같은 구조 —
**Core**(계약 계층 `APIKit`) / **Backends**(실행 `APIKitSupabase`). 계층은 디렉토리로
표현하고, **product 는 외부 SDK 경계에서만** 쪼갠다(빌드 그래프를 가볍게 유지).

| product | 계층 | 내용 | 외부 의존성 | 상태 |
|---|---|---|---|---|
| `CoreKit` | — | Info.plist 설정 로더(`ConfigValues`), `TopMostPresenter`, 캐시 프리미티브(`MemoryCache`/`DiskCache`) | 없음 | ✅ |
| `AuthKit` | Core + Backend | Auth 코어(타입·프로토콜·`DefaultAuthService`·Mock) + **로그인 버튼**(SwiftUI/UIKit, ko·en·ja) + **`RESTAuthBackend`**(자체 서버, 표준 REST 계약) | 없음 | ✅ |
| `AuthKitApple` | Provider | Apple | 없음 (AuthenticationServices) | ✅ |
| `AuthKitGoogle` | Provider | Google | GoogleSignIn-iOS | ✅ |
| `AuthKitKakao` | Provider | Kakao (네이티브, OIDC) | kakao-ios-sdk | ✅ |
| `AuthKitSupabase` | Backend | Supabase (`SupabaseAuthBackend`) | supabase-swift | ✅ |
| `APIKit` | Core + Backend | 서버 API 계약 계층 — `APIClient`(`request`/`stream`), `Endpoint` 선언 메타데이터, 중립 `APIError`·envelope, `MockAPIClient` + **`RESTAPIClient`**(URLSession 백엔드, `.http` transport) | 없음 | ✅ |
| `APIKitSupabase` | Backend | `SupabaseAPIClient` — EF/RPC/DB/Storage/Realtime 라우팅, `mapServerError` 훅 | supabase-swift | ✅ |
| `ImageKit` | Core | 원격 이미지 파이프라인 — `ImageLoader`(메모리/디스크 캐시·dedup·재시도), `ImageDownsampler`, `RemoteImage`(SwiftUI)/`RemoteUIImage`(UIKit) | 없음 | ✅ |
| `PurchaseKit` / `AdsKit` / `AnalyticsKit` / Push | — | — | — | 예정 |

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
    // 주입 순서 = 버튼 노출 순서. 버튼 디자인도 provider 가 소유 — 생성자로 오버라이드.
    providers: [AppleAuthProvider(), KakaoAuthProvider()]
)

let result = try await authService.signIn(with: .apple, presenter: nil)
```

로그인 버튼 (브랜드 스펙 + ko/en/ja, SwiftUI/UIKit) — 조립 시 등록한 provider 만
노출된다:

```swift
SocialLoginButtonStack(options: authService.loginOptions) { provider in
    signIn(provider)
}
.setCornerRadius(16)
.setIsLoading($isLoading)
```

상세: [docs/auth/05-app-integration.md](docs/auth/05-app-integration.md) ·
자체 서버·커스텀 provider: [docs/auth/08-custom-backend.md](docs/auth/08-custom-backend.md) ·
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
