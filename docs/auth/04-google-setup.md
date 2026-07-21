# 04. Google 설정

[console.cloud.google.com](https://console.cloud.google.com) 에서 진행.

## 1. 프로젝트 & OAuth 동의화면

1. GCP 프로젝트 생성(또는 기존 선택)
2. **APIs & Services → OAuth consent screen**
   - User Type: **External** → 앱 이름·지원 이메일 입력
   - Scopes 는 기본(email, profile, openid)이면 충분
   - 테스트 단계에선 Test users 에 본인 계정 추가, 출시 전 **Publish app**

## 2. iOS Client ID 생성

1. **APIs & Services → Credentials → Create Credentials → OAuth client ID**
2. Application type: **iOS** → Bundle ID 입력
3. 생성된 값 기록:
   - **Client ID** (`xxxx.apps.googleusercontent.com`) → `GOOGLE_CLIENT_ID`, Supabase Client IDs
   - **iOS URL scheme** (reversed client ID: `com.googleusercontent.apps.xxxx`) → URL scheme 등록용

## 3. Supabase 에 되먹이기

[01](01-supabase-setup.md)의 Google provider:
- **Client IDs** 에 iOS Client ID 입력
- ★ **Skip nonce checks** 켜기 — `GoogleAuthProvider` 는 nonce 를 보내지 않는다.
  안 켜면 로그인이 nonce mismatch 로 실패 ([07](07-troubleshooting.md))

## 4. 앱 쪽 사전 준비 메모 (상세는 [05](05-app-integration.md))

- URL scheme: reversed client ID (`com.googleusercontent.apps.xxxx`)
- `GoogleAuthProvider(clientID:)` 는 presenter 가 **필수** — 없으면
  `missingPresenter` 로 실패한다
