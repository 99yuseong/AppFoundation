# StorageSample — R2 업로드·표시 리허설 앱

`R2StorageClient` 경로(티켓제: Worker 서명 → 직접 PUT/GET)를 실제 인프라로
관통 검증하는 앱. Doran 등 실앱 전환 전 리허설 용도다.
전체 맥락: [docs/api/01-storage.md](../../docs/api/01-storage.md)

## 사전 조건 (전부 앱 밖 인프라)

1. **Supabase**: 프로젝트 하나 + Auth → **anonymous sign-in 활성** (JWT 공급원)
2. **R2**: 버킷 `storage-sample` 생성 + API 토큰 발급
3. **Worker**: `cloudflare/workers/storage-sign` README 대로 배포
   (R2 시크릿 2개 + JWT 검증 모드 — 새 비대칭 키 프로젝트는 vars 의
   SUPABASE_URL 만, legacy 는 시크릿 SUPABASE_JWT_SECRET)

## 실행

1. 로컬 설정 파일 생성 — 실값은 gitignore 대상이라 커밋되지 않는다:
   ```bash
   cp Config.xcconfig.template Config.xcconfig
   # SUPABASE_URL / SUPABASE_ANON_KEY / STORAGE_WORKER_URL 채우기
   # (xcconfig 는 // 가 주석이라 URL 은 https:/$()/ 로 끊어 쓴다 — template 참조)
   ```
   Info.plist 는 `$(변수)` 참조만 담고, 빌드 시 xcconfig 값이 치환된다.
2. `StorageSample.xcodeproj` 열고 실행 (로컬 패키지 참조 — 리포 루트)

## 검증 시나리오

| 단계 | 확인 |
|---|---|
| 익명 로그인 | uid 표시 (Worker 본인 폴더 검사의 기준값) |
| 업로드 | Worker 서명 1왕복 + PUT — 성공 시 정본 path 표시 |
| 표시 | 서명 URL 로 AsyncImage 렌더 (세션 없는 순수 GET) |
| 캐시 | "표시 URL 재요청" — 만료 전이면 `적중` (서명 왕복 없음) |

실패 시 에러 코드가 화면에 그대로 나온다 — `unauthorized`(JWT/시크릿 불일치),
`forbidden`(본인 폴더 밖), `sign_request_failed_*`(Worker 미배포/URL 오기),
`r2_upload_failed_*`(버킷 없음·CORS·서명 Content-Type 불일치).

## 참고

- 프로젝트 파일이 깨지면 Xcode 에서 같은 이름의 iOS App 프로젝트를 이 폴더에
  재생성하고 로컬 패키지(리포 루트)와 `APIKit`·`CoreKit`, 원격 `supabase-swift` 의
  `Supabase` product 를 다시 연결하면 된다 (소스는 StorageSample/ 폴더 그대로).
