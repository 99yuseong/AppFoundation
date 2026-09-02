# storage-sign — R2 presigned URL 발급 Worker

AppFoundation `R2StorageClient`(정확히는 `WorkerR2Signer`)의 서버 짝.
Supabase JWT 를 검증하고 본인 폴더 검사를 통과한 요청에 R2 presigned URL 을
발급한다. R2 키는 이 Worker 밖으로 나가지 않는다.

## 배포 (앱마다 인스턴스 하나)

1. `wrangler.toml` 에 앱 env 를 채운다 — `[env.<app>]` 의 `name`·`account_id`·
   `R2_ACCOUNT_ID`. account_id 는 그 앱 도메인 zone 이 있는 계정 (앱별 계정이
   기본 권고 — `docs/api/01-storage.md` 의 계정·쿼터 전략 참조).
2. JWT 검증 모드 선택 — Supabase 프로젝트의 키 체계에 따라:
   - **새 비대칭 키(ES256, 2025+ 신규 프로젝트 기본)**: vars 에
     `SUPABASE_URL` 만 추가 — JWKS 공개키로 검증, 시크릿 불필요
   - **legacy HS256**: `wrangler secret put SUPABASE_JWT_SECRET --env <app>`
   - 어느 쪽인지는 access token 헤더의 `alg` 로 확인 (`ES256` → JWKS, `HS256` → legacy)
3. R2 시크릿 주입:
   ```bash
   wrangler secret put R2_ACCESS_KEY_ID     --env <app>   # R2 API 토큰 (그 앱 버킷 범위)
   wrangler secret put R2_SECRET_ACCESS_KEY --env <app>
   ```
4. 배포: `wrangler deploy --env <app>` → 출력된 URL 을 앱 조립의
   `WorkerR2Signer(workerURL:)` 에 넣는다.

## 와이어 계약 (breaking 주의)

`WorkerR2Signer` 주석과 동일 — **AppFoundation 과 같은 태그로 버전되는 공개
계약**이다. 앱은 자기 kit 버전 태그의 템플릿으로 배포한다(버전 스큐 방지).
형태를 바꾸면 breaking — CHANGELOG 에 명시.

```
POST /   Authorization: Bearer {supabase access token}
{"items":[{"bucket","path","method","contentType"?,"expiresIn"}]}
→ 200 {"urls":[{"url","expiresAt"}]}          # items 순서 보존, all-or-nothing
→ 4xx {"ok":false,"error":{"code","message"}}
```

## 검증 로직

- JWT: JWKS(`SUPABASE_URL`/auth/v1/.well-known/jwks.json) 또는
  `SUPABASE_JWT_SECRET`(legacy HS256, 설정 시 우선) 검증 후 `sub` 추출
- 경로: 모든 item 의 `path` 가 `{sub}/` 접두여야 함 — storage RLS "본인 폴더"의
  대응물. 하나라도 실패 시 403 (all-or-nothing)
- method 는 GET·PUT·DELETE 만, expiresIn 상한 24h, 배치 상한 50개
