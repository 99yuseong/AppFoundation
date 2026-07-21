# 03. Kakao 설정

[developers.kakao.com](https://developers.kakao.com/console/app) 에서 진행.

## 1. 앱 생성 & 키 확인

1. **애플리케이션 추가하기** → 앱 이름/사업자명 입력
2. **[앱 설정 → 앱 키]** 에서 기록해 둘 값:
   - **네이티브 앱 키** → 앱의 `KAKAO_APP_KEY`, URL scheme, Supabase Client IDs
   - **REST API 키** → Supabase Client IDs
   - **어드민 키** → EF 의 `KAKAO_ADMIN_KEY` (탈퇴 unlink 용)

## 2. iOS 플랫폼 등록

**[앱 설정 → 플랫폼] → iOS 플랫폼 등록** → 번들 ID 입력

## 3. 카카오 로그인 활성화

1. **[제품 설정 → 카카오 로그인]** → 활성화 ON
2. ★ **[보안 → OpenID Connect] 활성화 ON — 필수**
   - OIDC 가 꺼져 있으면 SDK 가 **id_token 을 주지 않아**(nil) 로그인이
     `missingCredential` 로 실패한다. 가장 흔한 세팅 실수.
3. Redirect URI 는 네이티브 SDK 흐름에선 불필요 (웹 흐름 병용 시에만 등록)

## 4. 동의항목

**[제품 설정 → 카카오 로그인 → 동의항목]** 에서 필요한 항목 설정:
- 닉네임/프로필 사진: 보통 "필수 동의"
- 이메일: 비즈 앱 전환 후 가능 — id_token 의 email claim 에 실린다

## 5. Supabase 에 되먹이기

[01](01-supabase-setup.md)의 Kakao provider **Client IDs** 에
**REST API 키와 네이티브 앱 키를 콤마로 병기**한다. (네이티브 키 누락 =
id_token grant 400 — [07](07-troubleshooting.md) 참조)

## 6. 앱 쪽 사전 준비 메모 (상세는 [05](05-app-integration.md))

- URL scheme: `kakao{네이티브앱키}`
- `LSApplicationQueriesSchemes`: `kakaokompassauth`, `kakaolink`
- 앱 launch 시 `KakaoAuthProvider.initialize(appKey:)` 호출
