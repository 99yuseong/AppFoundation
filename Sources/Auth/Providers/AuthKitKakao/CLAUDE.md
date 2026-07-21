# AuthKitKakao (Auth / Providers 계층)

Kakao 네이티브 로그인 provider — KakaoSDK(OIDC) ↔ `AuthCredential.kakao` 변환만
담당한다. 이 product 를 추가하지 않으면 KakaoSDK 는 링크되지 않는다.

## 공개 API

- `KakaoAuthProvider` — `init(branding: SocialLoginBranding = .kakao)`
  - `static initialize(appKey:)` — 앱 launch 시 1회 (KakaoSDK.initSDK)
  - `authenticate`: 카카오톡 앱 스위치(설치 시) 또는 계정 로그인 →
    `.kakao(idToken, rawNonce)`. idToken nil 이면 콘솔 OIDC 미활성 —
    `missingCredential`
  - `handle(url)`: 카카오톡 앱 스위치 콜백 처리

## 불변 규칙 (검증된 gotcha — 바꾸지 말 것)

- **nonce 구도**: SDK 에는 SHA256(raw)을 주고 credential 에는 raw 를 담는다.
  백엔드(GoTrue)가 SHA256(요청 nonce) == claim 으로 검증하는 구도 (Apple 동일).
- **Swift 5 모드**: KakaoSDK 완료 핸들러가 Sendable 미표기 — v6 로 올리지 않는다.
- 취소 판정은 2종: 앱 스위치 `.Cancelled` + 계정 웹 `.AccessDenied`
  (`mapKakaoError` 는 internal — 단위 테스트 대상).

## 여기 넣지 말 것

- 세션 교환 — Supabase 라면 AuthKitSupabase 의 `KakaoIdTokenGrant`(GoTrue REST 우회)
