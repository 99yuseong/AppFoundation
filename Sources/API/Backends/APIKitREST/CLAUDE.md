# APIKitREST

`APIClient` 의 URLSession 실구현. 외부 의존이 없어 **별도 타깃이 아니다** —
AuthKitREST 선례대로 APIKit 타깃(`path: Sources/API`)에 폴더로 포함된다.
계층 구분(Backends/)은 디렉토리로만 표현한다.

## 책임

- `EndpointTransport.http` 선언 엔드포인트의 전송: `name` = path, `method` = verb,
  `task` = 페이로드 (.json/.query/.upload/.plain). Supabase 백엔드에선 선언용이던
  `method` 가 여기서 처음 실제 전송에 쓰인다.
- 상태코드 검증 + 에러 매핑: 실패 본문이 `{ok:false,error}` envelope 이면 code 를
  `mapServerError` 훅 → 중립 `APIError` 순으로 매핑 (SupabaseAPIClient 와 대칭).
  규약 밖 본문은 `http_<status>` 코드의 중립 에러.

## 경계

- **envelope 계약은 opt-in.** 기본 `unwrapping: .raw` — 응답 본문 전체가 Response 다.
  `{ok:true,data}` 언랩은 자기 서버(EF 와 동일 계약)를 붙일 때 `.envelope` 로 명시한다.
- 요청 가공은 `adapt` 클로저 하나 — 토큰 주입·공통 헤더는 이걸로 처리하고,
  Moya plugin 체계·per-endpoint headers 는 필요가 증명되기 전엔 추가하지 않는다.
- `stream` 미지원 (v1). SSE/WebSocket 은 실제 수요가 생길 때.
- verb 별 메서드 금지, transport 분기 최소 — APIKit CLAUDE.md 의 단일 진입 원칙을 따른다.
