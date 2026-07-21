---
name: auth-setup
description: AppFoundation AuthKit을 앱에 통합·세팅한다. Supabase 소셜 로그인(Apple/Kakao/Google)의 콘솔 설정 순서 안내와 코드 조립, 회원탈퇴 EF 배포까지. 신규 앱에 소셜 로그인을 붙이거나 기존 설정을 점검할 때 사용.
---

# AuthKit 통합 안내

너는 AppFoundation 의 AuthKit 을 이 앱에 통합하는 작업을 안내한다.
**진실의 원천은 `docs/auth/` 문서다** — 아래 절차에서 해당 문서를 실제로 읽고
그 내용대로 안내하라. 문서 내용을 기억에 의존해 재서술하지 마라.

이 스킬 파일 기준 repo 루트는 두 단계 상위다
(`.claude/skills/auth-setup/SKILL.md` → repo 루트). 앱 프로젝트에 symlink 로
설치된 경우 symlink 원본 위치를 기준으로 docs 경로를 해석하라.

## 절차

1. **사용 provider·백엔드 확인**: 사용자에게 어떤 소셜 로그인을 쓸지 묻는다
   (Apple / Kakao / Google — Apple 은 다른 소셜 로그인이 있으면 심사상 사실상 의무).
   백엔드도 확인한다 — Supabase 면 아래 콘솔 절차, **자체 API 서버면
   `docs/auth/08-custom-backend.md` 를 읽고 `AuthKitREST` 로 안내한다**
   (콘솔 절차 중 01-supabase 는 건너뛴다).

2. **현재 상태 파악**: 앱 프로젝트에서 다음을 확인한다:
   - AppFoundation SPM 이 이미 추가돼 있는지 (어떤 product 를 링크했는지)
   - Info.plist / xcconfig 에 관련 키가 있는지
     (`SUPABASE_PROJECT_ID`, `SUPABASE_API_KEY`, `KAKAO_APP_KEY`, `GOOGLE_CLIENT_ID`)
   - URL scheme 설정 여부

3. **콘솔 설정 안내**: `docs/auth/00-overview.md` 의 체크리스트 순서대로,
   선택된 provider 에 해당하는 문서만 읽고 안내한다:
   - `docs/auth/02-apple-setup.md` (Apple 선택 시)
   - `docs/auth/03-kakao-setup.md` (Kakao 선택 시 — OIDC 활성이 최다 빈도 실수)
   - `docs/auth/04-google-setup.md` (Google 선택 시)
   - `docs/auth/01-supabase-setup.md` (항상 — 위에서 얻은 키를 되먹이는 단계)

   콘솔 작업은 사용자가 웹에서 직접 해야 한다 — 단계별 체크리스트로 제시하고
   완료 확인 후 다음으로 넘어간다.

4. **코드 통합**: `docs/auth/05-app-integration.md` 를 읽고 이 앱의 구조
   (DI 방식, UIKit/SwiftUI)에 맞게 조립 코드를 작성한다.
   - product 는 사용하는 provider 것만 추가하게 한다
   - Info.plist·entitlements·pbxproj 수정은 개발자가 Xcode 에서 하도록 안내만 한다
   - SupabaseClient 는 앱 전역 하나를 주입한다 (새로 만들지 않는다)

5. **회원탈퇴**: 계정 생성이 있는 앱이면 `docs/auth/06-edge-functions.md` 를 읽고
   `account-withdraw` EF 배포와 클라이언트 탈퇴 흐름을 안내한다 (심사 의무).

6. **검증**: 빌드 통과 확인 후, 실기기/시뮬레이터 로그인 테스트는 사용자에게
   요청한다. 문제가 생기면 `docs/auth/07-troubleshooting.md` 를 읽고 대조한다.

## 주의

- Kakao 로그인 실패의 최다 원인: 콘솔 OIDC 미활성 (idToken nil) /
  Supabase Client IDs 에 네이티브 앱 키 누락 (grant 400)
- Google 로그인 실패의 최다 원인: Supabase "Skip nonce checks" 미설정
- Apple 은 native `signInWithIdToken` 흐름이라 Services ID / Secret Key 불필요
