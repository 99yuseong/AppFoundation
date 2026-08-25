# APIKitR2 (API / Backends 계층 — APIKit 타깃 포함)

Cloudflare R2 백엔드 — `StorageClient` 의 R2 실구현. 외부 의존 zero (URLSession 만
사용)라 별도 타깃 없이 **APIKit 타깃에 폴더로 포함**된다 (APIKitREST 선례).

## 공개 API

- `R2StorageClient` — `StorageClient` 구현. 업로드·다운로드 모두 티켓제
  (signer 에게 presigned URL 을 받아 URLSession 직접 PUT/GET). private 읽기 URL 은
  `SignedURLCache` 로 재사용. public 버킷 고정 URL 은 `publicBaseURLs`(버킷명 →
  커스텀 도메인) 생성자 설정에서 파생.
- `R2URLSigning` — 서명 발급 계약. 앱에 S3 키를 심지 않기 위한 경계.
- `WorkerR2Signer` — 기본 구현. 동봉 Worker 템플릿
  (`cloudflare/workers/storage-sign`)에 서명 위임. **와이어 계약(배열 기반
  items/urls)은 Worker 템플릿과 같은 태그로 버전되는 공개 계약** — 바꾸면 breaking,
  CHANGELOG 에 명시한다.

## 불변 규칙

- **S3 키·SigV4 계산을 이 타깃에 들이지 않는다** — 서명은 서버(Worker) 소관.
  aws-sdk 류 의존이 필요해 보이면 설계가 잘못된 것이다.
- Supabase 를 모른다 — 토큰은 `WorkerR2Signer.tokenProvider` 클로저 주입.
  조립에서 세션 소유자에 연결한다.
- 권한 정책(본인 폴더 검사)은 Worker 코드 소관 — 클라에서 선검사하지 않는다
  (서버 검증이 단일 진실 소스).

## 여기 넣지 말 것

- 외부 SDK import — 이 폴더는 APIKit 타깃이다 (의존 zero 유지)
- 앱 도메인 버킷 선언 — 앱 소관 (StorageBucket 준수 타입)
- Worker 배포 설정·시크릿 — cloudflare/ 와 각 앱 소관

## 관련 문서

- 구조·전환 체크리스트·계정 전략: `docs/api/01-storage.md`
