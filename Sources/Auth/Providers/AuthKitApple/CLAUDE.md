# AuthKitApple (Auth / Providers 계층)

Sign in with Apple provider — AuthenticationServices ↔ `AuthCredential.apple` 변환만
담당한다. 외부 SDK 는 없지만 provider 는 전부 `AuthKit{Provider}` product 라는
대칭 규칙으로 분리돼 있다.

## 공개 API

- `AppleAuthProvider` — `init(branding: SocialLoginBranding = .apple())`
  - `authenticate`: nonce 생성(SDK 엔 SHA256, credential 엔 raw) → ASAuthorization
    시트 → `.apple(idToken, rawNonce, authorizationCode, fullName, email)`
  - 취소는 `AuthKitError.cancelled` 로 매핑

## 여기 넣지 말 것

- 백엔드 로직(세션 교환·저장) — Backends 계층으로
- UI(버튼·화면) — AuthKit 의 branding 값으로만 디자인에 관여한다
- 소셜 토큰 revoke — 서버(Edge Function) 책임 (`docs/auth/06-edge-functions.md`)

## 메모

- `AppleAuthorizationContext` 는 delegate 콜백까지 self-참조로 생존하는 1회성 객체 —
  이중 resume 방지 구조를 유지할 것.
- Apple 은 클라이언트측 sign-out 이 없다 — `signOut`/`handle` 은 프로토콜 기본값.
