# AuthKitREST (Auth / Backends 계층 — `AuthKit` 타깃)

일반(자체) 서버용 백엔드 — 외부 의존 zero. kit 이 정의한 표준 계약
(`docs/auth/08-custom-backend.md`)을 앱 서버가 구현하면 바로 붙는다.

**타깃**: 이 폴더는 독립 타깃이 아니라 **`AuthKit` 타깃의 일부**다(의존성이 없어
빌드 그래프를 가볍게 두려고 Core 와 한 타깃으로 묶었다). 폴더는 계층 표현용으로
유지한다. 따라서 여기서 `import AuthKit` 은 하지 않는다 — 같은 모듈이다.
외부 SDK 의존이 생기는 순간에만 별도 타깃으로 분리한다.

## 공개 API

- `RESTAuthBackend` — `init(configuration:, store: = KeychainSessionStore(), urlSession:)`
  - `Configuration`: exchangeURL(필수), signOutURL?, additionalHeaders,
    encode/decode 오버라이드(계약이 다른 서버용)
  - `exchange`: 표준 body(provider/id_token/nonce/access_token, `.custom` 은
    parameters 병합) POST → `RESTSession` 저장 → `.signedIn` 방출
  - `events`: 브로드캐스트 스트림 — 구독 시작 시 저장 세션으로
    `.initialSessionLoaded` 1회 방출
- `RESTSession` — 표준 응답 `{access_token, refresh_token?, uid, email?}` 미러
- `SessionStoring` — `KeychainSessionStore`(기본) / `InMemorySessionStore`(테스트)

## 범위 (v1)

- **access token 자동 갱신은 범위 밖** — 만료 토큰을 쓰는 앱은 `AuthBackend` 를
  직접 구현한다 (08 문서 안내). 여기에 갱신 로직을 덧대지 말 것.
- signOut 서버 실패는 삼키지 않는다 — 무시가 필요한 흐름은
  `AuthService.endSession()` 이 담당.

## 여기 넣지 말 것

- provider SDK import / UI
- 특정 서버 프레임워크 종속 로직 — 계약(JSON)으로만 대화한다
