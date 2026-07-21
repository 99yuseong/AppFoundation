# AuthKit (Auth / Core 계층)

Auth 도메인의 코어 — 타입·프로토콜·오케스트레이터·로그인 버튼. provider SDK 와
백엔드 SDK 를 전혀 모른다(시스템 프레임워크만 의존). 앱은 이 모듈의 API 로만
Auth 를 다루고, 구현은 Providers/Backends 타겟이 공급한다.

## 공개 API

- **Entity**: `SocialProvider`(열린 String struct), `AuthCredential`(+`.custom`),
  `AuthIdentity`, `AuthEvent`, `SignInResult`, `WithdrawalCredential`, `SignOutScope`
- **Interface**: `AuthProvider`(credential 획득 + `branding` 소유),
  `AuthBackend`(세션 교환·수명주기), `AuthService`(앱 진입점, `loginOptions` 포함),
  `AuthPresenter`
- **Service**: `DefaultAuthService`(backend + providers 조립, 주입 순서 보존)
- **UI**: `SocialLoginBranding`/`SocialLoginOption`,
  `SocialLoginButton(Stack)`(SwiftUI) / `SocialLoginUIButton(Stack)`(UIKit),
  `SocialLoginLogo`(CGPath 브랜드 자산), `AppleLoginStyle`
- **Support**: `NonceGenerator`(bias-free, SDK 엔 SHA256/백엔드엔 raw 구도)
- **Mock**: `MockAuthService`
- **Resources**: `Localizable.xcstrings` (ko/en/ja — 버튼 문구의 단일 원천)

## 불변 규칙

- **SDK import 금지** — provider/백엔드 SDK 가 필요한 코드는 해당 계층 타겟으로.
- **버튼에 provider switch 금지** — 디자인은 주입된 `SocialLoginOption.branding` 만
  그린다. 새 provider 는 branding 값 하나로 노출된다.
- `SocialProvider` 를 enum 으로 되돌리지 않는다 (개방성이 버튼 OCP 의 전제).
- 뷰 컴포넌트는 `set~` 빌더 모디파이어 + SwiftUI·UIKit 양쪽 제공 (루트 CLAUDE.md).

## 관련 문서

- 아키텍처·계층: `docs/auth/00-overview.md`
- 커스텀 provider/backend 확장: `docs/auth/08-custom-backend.md`
