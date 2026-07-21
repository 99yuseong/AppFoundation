# AuthKitGoogle (Auth / Providers 계층)

Google 로그인 provider — GoogleSignIn-iOS ↔ `AuthCredential.google` 변환만 담당한다.
이 product 를 추가하지 않으면 GoogleSignIn SDK 는 링크되지 않는다.

## 공개 API

- `GoogleAuthProvider` — `init(clientID: String, branding: SocialLoginBranding = .google)`
  - `authenticate`: GIDSignIn 피커(presenter 필수) → `.google(idToken, accessToken)`
    (accessToken 은 탈퇴 시 서버 revoke 용 — idToken 은 revoke 불가)
  - `signOut`/`handle(url)`: GIDSignIn 위임

## 여기 넣지 말 것

- 백엔드 로직·UI — 각각 Backends 계층·AuthKit branding 으로
- nonce — Google 은 nonce 미사용 (Supabase 콘솔 "Skip nonce checks")

## 메모

- `configureIfNeeded` 는 GIDSignIn 전역 구성이 비어있을 때만 세팅한다 —
  앱이 직접 구성했다면 존중한다.
