# Storage — 계약·구현·전환 가이드

오브젝트 저장(업로드)과 표시(다운로드 URL)를 저장소 중립으로 다루는 계층.
**Supabase Storage ↔ Cloudflare R2 교체가 조립 한 줄**이 되는 것이 설계 목표다.

## 구조

```
StorageClient (APIKit — 중립 계약: upload / url)
├── SupabaseStorageClient   (APIKitSupabase — Storage SDK, 세션 JWT + RLS)
├── R2StorageClient         (APIKit 내 Backends/APIKitR2 — 티켓제 presign, 의존 zero)
└── MockStorageClient       (APIKit — 테스트)

StorageBucket (중립 디스크립터 — 버킷명·isPublic·signedURLExpiry 의 단일 출처)
SignedURLCache (서명 URL 재사용 — 만료 80% 창)
```

- 앱은 버킷을 `StorageBucket`(또는 `SupabaseBucket` — 이를 상속) 준수 타입으로
  선언하고, endpoint 는 `StorageContext.storage` 로만 실행한다.
- **DB 에는 URL 이 아니라 path 를 저장한다** — upload 반환값이 정본. URL 은
  `url(for:path:)` 로 그때그때 파생하므로, 저장소를 바꿔도 데이터는 그대로다.

## 업로드 / 다운로드 메커니즘

|  | Supabase Storage | R2 |
|---|---|---|
| 업로드 | [인증+전송] 한 번 — SDK 가 세션 JWT 첨부, RLS 검사 | [티켓][PUT] 두 번 — Worker 서명 후 직접 PUT |
| private 읽기 | [티켓][GET] — createSignedURL 후 순수 GET | [티켓][GET] — Worker presign 후 순수 GET |
| public 읽기 | 고정 URL (getPublicURL) | 커스텀 도메인 + path (CDN 캐시 통과) |
| 권한 정책 | storage RLS (SQL 선언) | Worker 코드 — `path` 접두 = 토큰 `sub` |

서명 URL 은 발급마다 달라지는 휘발성 파생물이다 — 표시 캐시 키는 path 로,
전송에만 서명 URL 을 쓴다. `SignedURLCache` 가 만료 80% 까지 재사용해 서명
요청(R2 는 Worker 무료 한도 10만 req/일)을 절감한다.

## 조립

```swift
// 기본 — Supabase Storage (주입 생략 시 자동)
let api = SupabaseAPIClient(client: supabase)

// R2 전환 — 이 한 줄이 교체의 전부
let api = SupabaseAPIClient(
    client: supabase,
    storage: R2StorageClient(
        signer: WorkerR2Signer(
            workerURL: URL(string: "https://doran-storage-sign.<계정>.workers.dev")!,
            tokenProvider: { try await supabase.auth.session.accessToken }
        ),
        publicBaseURLs: ["covers": URL(string: "https://cdn.doran.app")!]   // public 버킷만
    )
)
```

## R2 전환 체크리스트 (앱별, 전부 전환 시점에)

1. **Cloudflare 계정** — 아래 계정·쿼터 전략 참조 (앱별 계정 기본)
2. **R2 버킷 생성** + API 토큰 발급 (그 앱 버킷 범위로 최소화)
3. **CORS 설정** — 앱의 PUT/GET 허용
4. **public 버킷이면 커스텀 도메인 연결** (같은 계정 zone 필수)
5. **Worker 배포** — `cloudflare/workers/storage-sign` README 순서대로
   (시크릿 3개 + `wrangler deploy --env <app>`). **자기 kit 버전 태그의 템플릿**으로
   배포한다 — 와이어 계약이 태그 단위로 클라이언트와 짝이다 (버전 스큐 방지)
6. **오브젝트 이전** — Supabase Storage 의 S3 호환 endpoint 에서
   `rclone sync` 로 R2 에 복사 (DB 는 path 정본이라 무변경)
7. **조립 교체** — 위 R2StorageClient 주입 한 줄 → 릴리스

## 계정·쿼터 전략 — 앱별 계정이 기본

무료 한도는 **계정 단위**로 공유된다:

- R2 스토리지 10GB/월 — 초과는 hard stop 이 아니라 과금($0.015/GB·월, 100GB ≈ $1.5)
- Workers 10만 req/일 — **무료 플랜은 초과 시 요청 실패** = 서명 중단 → 업로드·
  private 표시 정지 (public 읽기는 Worker 를 안 타므로 무사)

**앱별 Cloudflare 계정이 기본 권고**인 이유:

- R2 커스텀 도메인은 그 도메인 zone 이 **같은 계정**에 있어야 한다 → 앱 도메인을
  따라 계정이 정해진다 (도메인-계정 일치)
- 무료 한도가 앱마다 ×1 로 곱해지고, 한 앱의 폭주가 다른 앱의 서명을 멈추지 않는다
- 앱 매각·사업 분리 시 계정째 이관하면 끝

관리는 리포에서: `wrangler.toml` 의 `[env.<app>].account_id` + 앱별 API 토큰으로
배포한다. 관리 단순이 우선이면 공유 계정 + Workers Paid($5/월, 1,000만 req/월)도
가능하지만, 시크릿·한도·과금의 반경이 전 앱이 된다는 점을 감수해야 한다.

## Doran 마이그레이션 노트 (교체 준비 시)

additive 승격이라 **버전만 올리면 무수정 컴파일**된다. R2 전환 준비를 원할 때:

- 버킷 2파일: `SupabaseBucket` 준수 그대로 (+필요 시 `signedURLExpiry` 오버라이드 —
  기존 endpoint 상수를 버킷으로 이동)
- 업로드 endpoint: `Bucket.upload(..., using: context.client)` →
  `context.storage.upload(_, to: Bucket.self, path:, contentType:)`
- signed URL endpoint 3파일: `context.client.storage...createSignedURL` →
  `context.storage.url(for: Bucket.self, path:)`

## 이름 충돌 주의

supabase-swift 도 `SupabaseStorageClient`(`client.storage` 의 타입)를 정의한다.
앱이 이 타입명을 직접 쓸 일은 드물지만(주입 생략 시 기본 생성), 두 모듈을 import
한 파일에서는 `APIKitSupabase.SupabaseStorageClient` 로 한정한다.
