# AuthKit 개요

소셜 로그인(Apple / Kakao / Google + 앱 정의 provider)을 앱에 빠르게 붙이기 위한
모듈. 백엔드는 Supabase(`AuthKitSupabase`)와 일반 자체 서버(`RESTAuthBackend` —
`AuthKit` 내장)를 제공하며, Firebase 등은 `AuthBackend` 직접 구현으로 확장한다.

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
- [ ] [08. 커스텀 백엔드·provider](08-custom-backend.md) — 자체 서버(REST 계약),
      Firebase 확장, 앱 정의 provider (자체 서버 앱은 01 대신 이 문서)

## 아키텍처 — 3계층 (디렉토리 = 계층)

```
Sources/Auth/
├── Core/       AuthKit             타입·프로토콜·오케스트레이터·로그인 버튼 (SDK 무의존)
├── Providers/  AuthKitApple        credential 획득 — provider SDK 소유
│               AuthKitGoogle
│               AuthKitKakao
└── Backends/   AuthKitSupabase     credential ↔ 세션 교환 — 세션 수명주기 소유
                AuthKitREST/        RESTAuthBackend (일반 자체 서버, 외부 의존 zero)
```

**계층 ≠ 타깃.** 계층은 디렉토리로 표현하고, 타깃(product)은 **외부 SDK 경계**에서만
쪼갠다 — 타깃이 늘수록 빌드 그래프만 무거워진다. 그래서 의존성이 없는
`Core/AuthKit` 과 `Backends/AuthKitREST` 는 **`AuthKit` 한 타깃**으로 묶여 있다
(폴더는 계층대로 유지). SDK 를 물고 있는 Providers·AuthKitSupabase 만 별도 product 다.

- **AuthProvider**: provider SDK 를 소유하고 로그인 UI 를 띄워 `AuthCredential`(idToken 등)을
  얻는다. 로그인 버튼 branding 도 provider 가 소유한다(생성자 주입).
- **AuthBackend**: credential 을 백엔드 세션과 교환하고 세션 수명주기(저장·갱신·이벤트)를
  소유한다. Supabase ↔ 자체 서버 ↔ Firebase(직접 구현)를 갈아끼우는 지점.
- **DefaultAuthService**: 둘을 조립하는 진입점. 앱은 이것만 쓴다. 주입한 provider
  목록이 `loginOptions` 로 UI 노출 목록까지 결정한다(주입 순서 = 노출 순서).

## Product 선택표

| product | 계층 | 내용 | 외부 의존성 |
|---|---|---|---|
| `AuthKit` | Core + Backend | 코어 타입·프로토콜·오케스트레이터·Mock + 로그인 버튼(SwiftUI/UIKit) + **`RESTAuthBackend`**(자체 서버) | 없음 (시스템 프레임워크만) |
| `AuthKitApple` | Provider | Apple | 없음 (AuthenticationServices) |
| `AuthKitGoogle` | Provider | Google | GoogleSignIn-iOS |
| `AuthKitKakao` | Provider | Kakao | kakao-ios-sdk |
| `AuthKitSupabase` | Backend | Supabase | supabase-swift |
| `CoreKit` | — | Info.plist 설정 로더, TopMostPresenter | 없음 |

앱은 `AuthKit` + **사용하는 provider product 만** 추가한다. Supabase 를 쓰면
`AuthKitSupabase` 를 더하고, 자체 서버면 `AuthKit` 에 내장된 `RESTAuthBackend` 를
쓰므로 추가 product 가 없다. provider 는 전부 `AuthKit{Provider}` 대칭 규칙 —
Kakao 를 안 쓰는 앱은 `AuthKitKakao` 를 추가하지 않으면 KakaoSDK 가 링크되지 않는다.

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
- **SocialProvider 는 열린 struct**: 닫힌 enum 이 아니라 String 기반 — 앱이 kit
  수정 없이 자체 provider 를 정의한다(`.custom` credential + [08 문서](08-custom-backend.md)).
  버튼도 provider switch 없이 주입된 branding 만 그린다.
