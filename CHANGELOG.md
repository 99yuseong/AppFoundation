# Changelog

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
