# AuthKitSupabase (Auth / Backends 계층)

Supabase 백엔드 — provider credential ↔ Supabase 세션 교환과 세션 수명주기를
담당한다. supabase-swift 에 의존한다.

## 공개 API

- `SupabaseAuthBackend` — `init(client: SupabaseClient, configuration:)`
  - `exchange`: apple/google 은 `signInWithIdToken`, kakao 는 GoTrue REST 우회,
    `.custom` 은 `unknownProvider` throw (앱 정의 provider 는 REST/직접 구현으로)
  - `Configuration`: Kakao REST grant 용 supabaseURL/apiKey + additionalHeaders

## 불변 규칙

- **SupabaseClient 는 앱이 주입** — 앱 전역에 하나여야 세션이 REST Bearer 에 실린다.
  패키지가 자체 클라이언트를 만들지 않는다.
- `KakaoIdTokenGrant.swift` 는 격리 파일 — supabase-swift 가 kakao id_token grant 를
  지원하면 이 파일만 삭제하고 `.kakao` 분기를 `signInWithIdToken` 으로 교체한다.
- supabase-swift 도 `SignOutScope` 를 export 하므로 `AuthKit.SignOutScope` 모듈 한정 유지.

## 여기 넣지 말 것

- provider SDK(KakaoSDK 등) import — credential 은 이미 값으로 도착한다
- UI

## 관련 문서

- 콘솔 설정: `docs/auth/01-supabase-setup.md` / 결정 로그: `docs/auth/00-overview.md`
