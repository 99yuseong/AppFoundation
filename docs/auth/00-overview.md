# AuthKit 개요

Supabase 기반 소셜 로그인(Apple / Kakao / Google)을 앱에 빠르게 붙이기 위한 모듈.

## 신규 앱 세팅 순서

아래 번호 순서대로 진행한다. 02~04에서 얻은 키를 01(Supabase 콘솔)에 되먹이는
순환이 있으므로, 실제로는 **02~04 provider 콘솔 작업 → 01 Supabase provider 활성 →
05 앱 통합 → 06 Edge Function** 순서가 자연스럽다.

- [ ] [01. Supabase 설정](01-supabase-setup.md) — 프로젝트 생성, Auth provider 활성
- [ ] [02. Apple 설정](02-apple-setup.md) — App ID Capability, revoke 용 Key(.p8)
- [ ] [03. Kakao 설정](03-kakao-setup.md) — 앱 생성, **OpenID Connect 활성(필수)**
- [ ] [04. Google 설정](04-google-setup.md) — OAuth iOS Client ID
- [ ] [05. 앱 통합](05-app-integration.md) — SPM 추가, 키/URL scheme, 조립 코드
- [ ] [06. Edge Functions](06-edge-functions.md) — account-withdraw 배포
- [ ] [07. 트러블슈팅](07-troubleshooting.md)

## 아키텍처 — 3분할

```
AuthProvider (credential 획득)          AuthBackend (credential → 세션 교환)
  AppleAuthProvider  (AuthKitApple)       SupabaseAuthBackend (AuthKitSupabase)
  GoogleAuthProvider (AuthKitGoogle)      (추후 FirebaseAuthBackend 추가 가능)
  KakaoAuthProvider  (AuthKitKakao)
                └──── DefaultAuthService (오케스트레이터, SDK 무의존) ────┘
```

- **AuthProvider**: provider SDK 를 소유하고 로그인 UI 를 띄워 `AuthCredential`(idToken 등)을 얻는다.
- **AuthBackend**: credential 을 백엔드 세션과 교환하고 세션 수명주기(저장·갱신·이벤트)를 소유한다.
- **DefaultAuthService**: 둘을 조립하는 진입점. 앱은 이것만 쓴다.

## Product 선택표

| product | 내용 | 외부 의존성 |
|---|---|---|
| `AuthKit` | 코어 타입·프로토콜·오케스트레이터·Mock + 로그인 버튼(SwiftUI/UIKit) | 없음 (시스템 프레임워크만) |
| `AuthKitApple` | Apple provider | 없음 (AuthenticationServices) |
| `AuthKitSupabase` | Supabase 백엔드 | supabase-swift |
| `AuthKitGoogle` | Google provider | GoogleSignIn-iOS |
| `AuthKitKakao` | Kakao provider | kakao-ios-sdk |
| `CoreKit` | Info.plist 설정 로더, TopMostPresenter | 없음 |

앱은 `AuthKit` + `AuthKitSupabase` + **사용하는 provider product 만** 추가한다.
provider 는 전부 `AuthKit{Provider}` 대칭 규칙 — Kakao 를 안 쓰는 앱은
`AuthKitKakao` 를 추가하지 않으면 KakaoSDK 가 링크되지 않는다.

## 결정 로그

- **Kakao 는 GoTrue REST 우회**: supabase-swift 의 `OpenIDConnectCredentials.Provider`
  에 kakao 가 없어(google/apple/azure/facebook만) `AuthKitSupabase/KakaoIdTokenGrant.swift`
  가 GoTrue `/auth/v1/token?grant_type=id_token` 을 직접 호출한 뒤 `setSession` 으로
  주입한다. SDK 가 kakao 를 지원하면 이 파일만 삭제하면 된다.
- **nonce 구도 (Apple·Kakao 공통)**: GoTrue 는 SHA256(요청 nonce) == id_token nonce
  claim 으로 검증한다. SDK 요청에는 해시를, GoTrue 에는 raw 를 준다.
- **Google 은 nonce 미사용**: Supabase 콘솔에서 "Skip nonce checks" 를 켠다.
- **탈퇴 표준 = 재인증형 하이브리드**: Apple·Google 은 탈퇴 직전 재인증으로 fresh
  credential 확보 → 서버가 즉석 revoke. Kakao 는 admin key 서버 unlink.
  서버에 장기 자격증명을 보관하지 않는다. [06 문서](06-edge-functions.md) 참조.
- **SupabaseClient 는 앱이 주입**: 앱 전역에 클라이언트는 하나여야 로그인 세션이
  REST 요청 Bearer 에 실린다. 패키지는 자체 클라이언트를 만들지 않는다.
