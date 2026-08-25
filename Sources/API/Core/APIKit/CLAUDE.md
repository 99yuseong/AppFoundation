# APIKit (API / Core 계층)

서버 API 의 **계약 계층** — 앱단에서 EF/RPC/DB/Storage/Realtime 을 하나의 API 로
간주하게 하는 타입·프로토콜. 외부 SDK 무의존.

## 공개 API

- `APIClient` — `request(_:)` 단발 호출 / `stream(_:)` 구독. 진입점은 이 둘뿐.
- `Endpoint` — `name`·`transport`·`method`·`task` 선언 메타데이터 (Moya TargetType 상당)
- `EndpointTransport`·`HTTPMethod` — 개방형 String struct (`SocialProvider` 선례)
- `EndpointTask` — `.plain`/`.json`/`.query`/`.upload` 페이로드 분류
- `APIError` — 중립 에러 + code/envelope 매핑, `APIEnvelope`/`APIErrorEnvelope` — `{ok,data}` 계약
- `ServerErrorDetails` — 실패 본문의 `code`/`message` **밖 필드**를 앱까지 전달.
  백엔드가 채우고 `mapServerError` 훅이 `decode(_:)`/`string(forKey:)` 로 읽는다
- `EndpointKey` — name+transport 식별자 (목/기록용), `MockAPIClient`, `EmptyResponse`
- `CurrentUserIDProviding` — 본인 행 특정용 유저 id 제공 인터페이스
- **Storage/** — `StorageClient`(오브젝트 저장소 실행 계약: upload/url),
  `StorageBucket`(버킷명·공개 여부·`signedURLExpiry` 만료 정책 디스크립터),
  `SignedURLCache`(서명 URL 만료 80% 창 재사용 — 서명 요청 절감), `MockStorageClient`.
  구현은 `SupabaseStorageClient`(APIKitSupabase)와 `R2StorageClient`(Backends/APIKitR2 —
  의존 zero 라 이 타깃 포함). 상세: `docs/api/01-storage.md`

## 불변 규칙

- **verb 별 메서드(get/post…)를 APIClient 에 추가하지 않는다** — 전송 세부가
  호출부(Repository)에 새면 백엔드 이전 시 호출부가 바뀐다. `method`/`task` 는
  엔드포인트 선언 메타데이터이며 **강제 없음**(선언과 조합을 컴파일/런타임에서 막지 않는다).
- `EndpointTransport`/`HTTPMethod` 는 개방형 유지 — 새 백엔드/앱이 kit 수정 없이
  자체 값을 정의한다. 백엔드는 모르는 transport 를 에러로 드러낸다.
- baseURL/헤더는 백엔드 소유 — 엔드포인트가 호스트를 모르는 것이 교체 무변경의 전제.
- 앱 전용 에러 코드를 `APIError` 케이스로 승격하지 않는다 — 백엔드의 `mapServerError`
  훅으로 앱이 매핑한다.
- **같은 이유로 실패 본문의 부가 필드를 `ServerErrorDetails` 의 프로퍼티로 올리지
  않는다** — 어떤 키가 오는지는 앱·서버 계약이다. kit 은 원본만 들고 있고 해석은 앱이 한다.
  `details` 는 `{ok:false,error}` 본문이 있는 경로(EF/REST)에서만 채워진다 —
  RPC 는 예외로 실패를 알리므로 구조화된 값이 필요하면 EF 로 두거나 성공 응답에 싣는다.

## 여기 넣지 말 것

- 백엔드 SDK import (supabase-swift 등) — Backends 타겟 소관
- 앱 도메인 엔드포인트/DTO — 앱 소관
- UI

## 관련 문서

- 개념·비용 원칙·서버 확장 스토리: `docs/api/00-overview.md`
- Storage 계약·R2 전환·계정 전략: `docs/api/01-storage.md`
