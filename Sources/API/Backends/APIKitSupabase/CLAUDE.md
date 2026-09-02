# APIKitSupabase (API / Backends 계층)

Supabase 백엔드 — `APIClient` 의 실구현. transport 라우팅(EF/RPC 는 직접 전송,
DB/Storage/Realtime 은 엔드포인트에 SDK 실행 컨텍스트 제공)과 에러 매핑을 담당한다.
supabase-swift 에 의존한다.

## 공개 API

- `SupabaseAPIClient` — `init(client:userIDProvider:storage:mapServerError:)`
  - `request`: edgeFunction(`functions.invoke` + `{ok,data}` 해체) / rpc(배열-first
    디코드) / database·storage(엔드포인트 직접 실행) 라우팅. realtime 은 에러.
  - `stream`: `.realtime` 엔드포인트 전용 구독 진입점
  - `mapServerError` 훅: 서버 (code, message, details) → 앱 도메인 에러. nil 폴백 시 중립
    `APIError`. `details`(`ServerErrorDetails`)는 `{ok:false,error}` 본문이 있는 **EF
    경로에서만** 채워진다 — RPC 는 PostgrestError 예외라 구조화된 본문이 없어 항상 nil
  - `withSimpleErrorMapping(client:userIDProvider:mapServerError:)` — details 가 필요 없을
    때 쓰는 2인자 훅 팩토리 (init 오버로드로 두면 클로저 타입이 문맥 의존이라 `self.init`
    이 자기 자신으로 해소돼 무한 재귀가 된다 — 그래서 이름을 달리한 팩토리다)
- `DatabaseEndpoint`/`StorageEndpoint`/`RealtimeEndpoint` + 각 Context — 엔드포인트가
  SDK 로 직접 실행하는 경로의 프로토콜 (Context 가 SupabaseClient 노출).
  `StorageContext` 는 `storage: any StorageClient`(중립 계약)도 실어 나른다 —
  storage 실행은 이 경유를 권장 (저장소 교체가 조립 주입으로 끝난다)
- `SupabaseStorageClient` — `StorageClient` 의 Supabase 실구현 (upsert 업로드,
  public/서명 URL 분기, `SignedURLCache` 경유, remove 삭제). supabase-swift 의 동명 타입
  (client.storage)과 겹치므로 필요 시 `APIKitSupabase.` 한정
- `SupabaseTable`/`SupabaseBucket` — 테이블·버킷명 단일 출처 네임스페이스 프로토콜.
  `SupabaseBucket` 은 APIKit `StorageBucket` 을 상속(기존 준수 타입 무수정 승격)
- `SupabaseSessionUserIDProvider` — 세션 uid 기본 구현 (서비스 id 별도인 앱은 자체 주입)

## 불변 규칙

- **SupabaseClient 는 앱이 주입** — 앱 전역에 하나여야 하고, AuthKitSupabase 의
  `SupabaseAuthBackend` 와 **같은 인스턴스**여야 세션이 서버 호출 Bearer 에 실린다.
  패키지가 자체 클라이언트를 만들지 않는다.
- **엔드포인트 안의 SDK 로직은 의도된 임시 구조** — EF 호출 수 제한(비용)을 피하는
  클라 조합 경로다. Context 의 SupabaseClient 노출을 추상화로 가리지 않는다(SDK 전
  기능 활용이 원칙). 자체 서버 확장 시 이 로직이 서버로 이동한다.
  **storage 만 한정 예외** — 저장소는 교체축(Supabase ↔ R2)이라 `StorageContext.storage`
  중립 계약 경유를 권장한다. client 는 그대로 노출을 유지하므로 규칙 위반이 아니라
  storage 에 국한된 추가 경로다.
- 앱 전용 에러 코드(제재 등)를 여기 하드코딩하지 않는다 — `mapServerError` 훅 소관.
- `method`/`task` 는 전송에 강제하지 않는다 — EF/RPC 는 `.json` task 만 소비, method 는
  로그 가시화용.

## 여기 넣지 말 것

- 앱 도메인 엔드포인트/DTO/테이블·버킷 구현 — 앱 소관
- Auth(로그인·세션 교환) 로직 — AuthKitSupabase 소관
- UI

## 관련 문서

- 개념·비용 원칙·서버 확장 스토리: `docs/api/00-overview.md`
- Storage 계약·R2 전환·계정 전략: `docs/api/01-storage.md`
