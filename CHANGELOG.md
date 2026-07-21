# Changelog

## 0.3.0 (2026-07-21)

### 추가
- `AuthKitREST`: 일반(자체) 서버용 백엔드 (외부 의존 zero) — 표준 REST 계약
  (`docs/auth/08-custom-backend.md`), `RESTSession`, `SessionStoring`
  (Keychain 기본/InMemory), 계약이 다른 서버용 encode/decode 오버라이드
- 개방형 provider: `AuthCredential.custom(provider:parameters:)` /
  `WithdrawalCredential.custom` — 앱 정의 provider 를 kit 수정 없이 추가
- provider 소유 브랜딩: `AuthProvider.branding`(기본값 내장 + 생성자 주입),
  `SocialLoginBranding`/`SocialLoginOption`, `AuthService.loginOptions`
  (주입 순서 = 노출 순서)
- `SocialLoginButtonStack`(SwiftUI) / `SocialLoginUIButtonStack`(UIKit) —
  `loginOptions` 를 받아 등록된 provider 만 노출
- 각 모듈 최상단 + 루트 `CLAUDE.md` — 모듈 책임·경계·컨벤션 명시
- `docs/auth/08-custom-backend.md` — 자체 서버 계약(서버 id_token 검증 포함),
  `AuthBackend` 직접 구현, 커스텀 provider 확장 가이드

### 변경 (breaking)
- `AppleAuthProvider` 를 `AuthKitApple` product 로 분리 — provider 는 전부
  `AuthKit{Provider}` 대칭 규칙. 사용 앱은 `AuthKitApple` product 추가 +
  `import AuthKitApple` 필요
- `SocialProvider`: enum → String 기반 struct (`CaseIterable` 제거 — 등록 목록은
  `AuthService.loginOptions` 가 대체)
- 로그인 버튼: `setProvider`/`setAppleStyle` 제거 — `SocialLoginOption` 주입으로
  대체 (`SocialLoginButton(option:action:)`, Apple 스타일은
  `AppleAuthProvider(branding: .apple(.whiteOutline))`)
- `AuthProvider` 에 `branding` 요구사항 추가 — 직접 구현한 provider 는 branding
  프로퍼티를 추가해야 함
- 디렉토리 재편: `Sources/Auth/{Core,Providers,Backends}/` (product 이름·API 불변)

## 0.2.0 (2026-07-21)

### 추가
- `SocialLoginButton` (SwiftUI) / `SocialLoginUIButton` (UIKit): 소셜 로그인 버튼 —
  `setProvider` 로 브랜드 전환(apple/google/kakao), `set~` 빌더 모디파이어
  (`setCornerRadius`/`setHeight`/`setIsLoading` 바인딩/`setAppleStyle`/`setOnTap`/`setLoading`)
- 로고 CGPath 공유 정의(`SocialLoginLogo`) — Kakao 말풍선, Google 4색 G (SwiftUI·UIKit 재사용)
- Localization: ko / en / ja (`Localizable.xcstrings`, `defaultLocalization: ko`)
- `Examples/AuthSample`: 데모 앱 (SwiftUI/UIKit 탭, Mock 기본, LiveAuthAssembly 실연결 예시)

## 0.1.0 (2026-07-21)

첫 릴리스 — Auth 도메인.

### 추가
- `CoreKit`: `ConfigValues`(Info.plist 설정 로더), `TopMostPresenter`
- `AuthKit`: 코어 타입(`SocialProvider`/`AuthIdentity`/`AuthEvent`/`AuthCredential`/
  `SignInResult`/`WithdrawalCredential`/`SignOutScope`/`AuthKitError`),
  프로토콜(`AuthProvider`/`AuthBackend`/`AuthService`), `DefaultAuthService`,
  `NonceGenerator`, `AppleAuthProvider`, `MockAuthService`
- `AuthKitGoogle`: `GoogleAuthProvider` (GIDSignIn)
- `AuthKitKakao`: `KakaoAuthProvider` (KakaoSDK 네이티브 + OIDC)
- `AuthKitSupabase`: `SupabaseAuthBackend`, Kakao GoTrue REST id_token grant 격리
  (`KakaoIdTokenGrant` — supabase-swift 가 kakao 지원 시 삭제)
- `supabase/functions/account-withdraw`: 회원탈퇴 표준 EF 템플릿 (재인증형 하이브리드)
- `docs/auth/00~07`: 콘솔 설정 순서·앱 통합·탈퇴·트러블슈팅 가이드
- `.claude/skills/auth-setup`: 신규 앱 통합 안내 스킬

### 출처
TumTumRead(Apple/Kakao)와 Doran(Apple/Google)의 검증된 Auth 구현을 통합·이식.
