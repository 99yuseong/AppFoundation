# 02. Apple 설정

[developer.apple.com/account](https://developer.apple.com/account) 에서 진행.

## 1. App ID 에 Capability 추가

1. **Certificates, Identifiers & Profiles → Identifiers** → 앱의 App ID 선택
   (없으면 생성: Bundle ID = 앱 번들 ID)
2. **Sign In with Apple** capability 체크 → Save

## 2. Xcode Capability 추가 (개발자가 Xcode에서)

1. 타겟 → **Signing & Capabilities → + Capability → Sign in with Apple**
2. `.entitlements` 에 `com.apple.developer.applesignin` 이 추가된다

## 3. (탈퇴 revoke 용) Key 생성 — .p8

`account-withdraw` EF 가 Apple `/auth/revoke` 를 호출할 때 서명용으로 쓴다.

1. **Keys → +** → 이름 입력 → **Sign in with Apple** 체크 → Configure 에서
   Primary App ID 선택 → 등록
2. **.p8 파일 다운로드 (1회만 가능 — 안전한 곳에 보관)**
3. 기록해 둘 값:
   - **Key ID** (10자) → `APPLE_KEY_ID`
   - **Team ID** (계정 우상단, 10자) → `APPLE_TEAM_ID`
   - .p8 파일 내용 → `APPLE_PRIVATE_KEY`

## 4. Supabase 에 되먹이기

[01](01-supabase-setup.md)의 Apple provider **Client IDs** 에 번들 ID 입력.

> **Services ID / Secret Key 는 만들지 않는다** — native `signInWithIdToken` 흐름은
> 번들 ID 만으로 동작하고, 6개월마다 갱신해야 하는 Secret Key 는 웹 OAuth 흐름
> 전용이다.

## 심사 유의사항

- 다른 소셜 로그인을 제공하면 Apple 로그인 제공이 사실상 의무 (심사 지침 4.8)
- 계정 생성이 있으면 **앱 내 계정 삭제** 제공 의무 + 탈퇴 시 Apple 토큰 revoke
  의무 (5.1.1(v)) → [06 account-withdraw](06-edge-functions.md)가 담당
