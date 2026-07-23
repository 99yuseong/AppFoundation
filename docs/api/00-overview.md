# API 도메인 개요 — APIKit · APIKitSupabase · APIKitREST

앱단에서 서버 호출(EF/RPC/DB/Storage/Realtime/HTTP)을 **하나의 API** 로 간주하게
하는 계약 계층. Doran-iOS 의 검증된 APIClient 구조를 이식했다.

```
Repository ──▶ APIClient (APIKit — 계약, SDK 무의존)
                  ├─ SupabaseAPIClient (APIKitSupabase — 실행, supabase-swift)
                  └─ RESTAPIClient (APIKitREST — URLSession 실행, 의존 zero → APIKit 타깃에 포함)
```

## 핵심 원칙

### 1. 비용 원칙 — 로직의 위치는 호출 수 제한이 정한다

- **Edge Function 은 호출 수 제한(과금)이 있다** → 서버 로직이 꼭 필요한 것만 EF 로.
- **RPC/DB/Storage/Realtime 은 제한이 없다** → 클라이언트가 Supabase SDK 를 직접
  조합해 호출한다. 이때 endpoint 구현(`executeDatabase` 등)에 SDK 로직이 들어가는
  것은 **의도된 임시 구조**다 — 과도한 추상화로 SDK 자유도를 잃지 않는 것이 원칙.

### 2. 단일 진입 — verb 는 메서드가 아니라 선언

`APIClient` 의 진입점은 `request(_:)`(단발)와 `stream(_:)`(구독) 둘뿐이다.
`api.get/post` 같은 verb 메서드를 만들지 않는다 — 전송 세부가 호출부(Repository)에
새면 백엔드 이전 시 호출부가 바뀐다. 대신 verb·페이로드는 endpoint 가 선언한다
(Moya `TargetType` 과 같은 구조):

```swift
enum UserEndpoint: DatabaseEndpoint {
    case updateName(UpdateNameRequest)

    var name: String { "users_update_name" }
    var transport: EndpointTransport { .database }
    var method: HTTPMethod { .patch }          // 선언적 — 강제 없음
    var task: EndpointTask { ... }             // .json(dto) 등 페이로드 분류

    func executeDatabase<Response: Decodable>(context:response:) async throws -> Response {
        // 클라 조합 경로 — context.client 로 SDK 전 기능 사용 (RLS + id 필터)
    }
}
```

선언 관례: EF/RPC → `.post`+`.json` / DB select → `.get` / insert → `.post` /
update → `.patch` / delete → `.delete` / storage upsert 업로드 → `.put`+`.upload` /
realtime 구독 → `.get`+`.plain`.

### 3. 서버 확장 마이그레이션 스토리

자체 서버로 확장하는 날, 변경은 이렇게 흐른다:

1. endpoint 의 `executeDatabase`/`executeStorage` 안 클라 조합 로직이 **서버로 이동**한다.
2. endpoint 는 선언만 바뀐다 — transport 를 `.http` 로 전환하면 `RESTAPIClient` 가
   이미 선언된 `method` 를 실제 전송 verb 로, `name` 을 URL path 로 사용한다.
3. **Repository 는 무변경** — `APIClient` 프로토콜만 보기 때문.

### 3.5 REST 백엔드 (`RESTAPIClient`)

`.http` transport 전용 URLSession 백엔드. 두 용도를 `unwrapping` 주입으로 흡수한다:

- `.raw` (기본): 응답 본문 전체가 Response — 서드파티/일반 REST API.
- `.envelope`: `{ok:true,data}` 의 data 만 디코딩 — 자기 서버(EF 와 동일 계약) opt-in.

```swift
let api: any APIClient = RESTAPIClient(
    baseURL: URL(string: "https://api.example.com/v1")!,
    adapt: { request in var r = request; r.setValue("Bearer …", forHTTPHeaderField: "Authorization"); return r },
    mapServerError: { code, _ in code == "account_banned" ? AppServerError.accountBanned : nil }
)
```

실패 본문이 envelope 계약이면 unwrapping 과 무관하게 code 를 뽑아 훅 매핑을 태운다.
per-endpoint headers·plugin 체계·`stream`(SSE)은 필요가 증명되면 추가한다.

### 4. 에러 — 중립 + 앱 훅

kit 은 `APIError`(invalidRequest/unauthorized/server) 중립 케이스만 소유한다.
앱 전용 코드(제재, 기기 이전 등)는 `SupabaseAPIClient(mapServerError:)` 훅으로
앱이 자기 도메인 에러에 매핑한다 — Repository 는 도메인 에러만 다룬다.

```swift
SupabaseAPIClient(client: supabase) { code, message in
    switch code {
    case "account_banned", "DR004": AppServerError.accountBanned
    default: nil   // nil → 중립 APIError 폴백
    }
}
```

## 통합 규칙

- **SupabaseClient 는 앱 전역 유일 인스턴스를 주입한다.** AuthKitSupabase 의
  `SupabaseAuthBackend` 와 **같은 인스턴스**여야 로그인 세션이 서버 호출의 Bearer
  토큰에 실린다. Composition Root 에서 하나 만들어 양쪽에 넘길 것.
- 본인 행 특정(id 필터)이 필요한 DB 조작은 `CurrentUserIDProviding` 을 쓴다.
  세션 uid 를 그대로 쓰면 기본 구현(`SupabaseSessionUserIDProvider`), 서비스 유저
  id 가 별도면 앱이 자체 구현을 주입.
- 테이블/버킷명은 `SupabaseTable`/`SupabaseBucket` 준수 타입(앱 소유)에 모은다 —
  문자열 산재 금지, 서버 GRANT/버킷 정의와 1:1.
- 테스트는 `MockAPIClient`(APIKit 포함) — `EndpointKey` 별 JSON 응답 주입 +
  `calledActions` 로 오케스트레이션 검증. 실서버·URLProtocol 스텁 불필요.

## product 추가

```swift
.product(name: "APIKit", package: "AppFoundation"),          // Repository 계층 (RESTAPIClient 포함)
.product(name: "APIKitSupabase", package: "AppFoundation"),  // Composition Root + endpoint 구현
```
