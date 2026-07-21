# 01. Supabase 설정

> 선행: [02 Apple](02-apple-setup.md) / [03 Kakao](03-kakao-setup.md) /
> [04 Google](04-google-setup.md) 콘솔에서 키를 먼저 만들어 와야 이 단계가 한 번에 끝난다.

## 1. 프로젝트 생성

1. [supabase.com/dashboard](https://supabase.com/dashboard) → **New project**
2. 생성 후 **Settings → API** 에서 두 값을 기록해 둔다 (05에서 사용):
   - Project URL 의 서브도메인 = `SUPABASE_PROJECT_ID` (예: `abcd1234`)
   - `anon` `public` API key = `SUPABASE_API_KEY`

## 2. Auth Provider 활성화

**Authentication → Sign In / Providers** 에서 사용할 provider 를 켠다.

### Apple

- **Enabled** 켜기
- **Client IDs**: 앱 **번들 ID** 입력 (예: `com.team.myapp`)
  - native `signInWithIdToken` 흐름은 번들 ID 만으로 동작한다.
    Services ID / Secret Key(6개월 갱신)는 **웹 OAuth 흐름에만** 필요 — 처음부터
    native 로 가면 만들 필요 없다.
  - Dev/Prod 번들이 다르면 콤마로 병기: `com.team.myapp,com.team.myapp.dev`

### Google

- **Enabled** 켜기
- **Client IDs**: [04](04-google-setup.md)에서 만든 **iOS Client ID** 입력
  (`xxxx.apps.googleusercontent.com`)
- ★ **Skip nonce checks** 를 **켠다** — `GoogleAuthProvider` 는 nonce 를 보내지
  않으므로 이걸 안 켜면 로그인이 nonce mismatch 로 실패한다.

### Kakao

- **Enabled** 켜기
- ★ **Client IDs**: [03](03-kakao-setup.md)의 **REST API 키와 네이티브 앱 키를
  콤마로 병기** (예: `{REST_API_KEY},{NATIVE_APP_KEY}`)
  - GoTrue 는 id_token 의 `aud` claim 을 Client IDs 목록과 대조한다. 네이티브
    SDK 로그인의 id_token 은 `aud`=네이티브 앱 키라서, 네이티브 키가 빠지면
    id_token grant 가 400 으로 실패한다.
- **Client Secret Code**: Kakao 콘솔 [보안]의 Client Secret (웹 흐름 병용 시)

## 3. (탈퇴 EF 용) secrets 등록

[06](06-edge-functions.md)의 `account-withdraw` 를 쓸 경우:

```bash
supabase secrets set \
  APPLE_TEAM_ID=XXXXXXXXXX \
  APPLE_CLIENT_ID=com.team.myapp \
  APPLE_KEY_ID=YYYYYYYYYY \
  APPLE_PRIVATE_KEY="$(cat AuthKey_YYYYYYYYYY.p8)" \
  KAKAO_ADMIN_KEY=zzzzzzzz
```
