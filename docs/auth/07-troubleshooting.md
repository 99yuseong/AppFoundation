# 07. 트러블슈팅

## Kakao

### 로그인이 `missingCredential` 로 실패 (idToken nil)
Kakao 콘솔 **[카카오 로그인 → 보안 → OpenID Connect]** 가 꺼져 있다.
OIDC 미활성이면 SDK 가 id_token 을 아예 주지 않는다. → [03](03-kakao-setup.md)

### id_token grant 가 HTTP 400 (`backendHTTP`)
Supabase Kakao provider 의 **Client IDs 에 네이티브 앱 키가 빠져 있다.**
GoTrue 는 id_token 의 `aud`(=네이티브 앱 키)를 Client IDs 와 대조하므로
REST API 키와 **콤마로 병기**해야 한다. → [01](01-supabase-setup.md)

### nonce mismatch 류 에러
SDK 에 해시(SHA256)를, GoTrue 에 raw nonce 를 줘야 한다. `KakaoAuthProvider` 를
그대로 쓰면 자동 처리되므로, 직접 SDK 를 호출하는 코드가 섞여 있는지 확인.

### 카카오톡 앱 전환 후 돌아오지 않음
- URL scheme `kakao{네이티브앱키}` 누락, 또는
- `.onOpenURL` / AppDelegate 에서 `authService.handle(url)` 연결 누락 → [05](05-app-integration.md)

## Google

### 로그인 성공 후 Supabase 교환에서 nonce 관련 실패
Supabase Google provider 의 **Skip nonce checks 가 꺼져 있다.**
`GoogleAuthProvider` 는 nonce 를 보내지 않으므로 반드시 켠다. → [01](01-supabase-setup.md)

### `missingPresenter(.google)`
Google 은 계정 피커를 띄울 presenter 가 필수다. `TopMostPresenter.topViewController()`
를 활용하거나 로그인 화면의 뷰컨트롤러를 넘긴다.

### 피커가 뜨지만 로그인 후 `invalid_client` 류
- GCP iOS Client ID 의 Bundle ID 와 앱 번들이 다르거나
- Supabase Client IDs 에 등록된 Client ID 가 다른 프로젝트의 것

## Apple

### `authorizationCode` 가 nil 이라 탈퇴 revoke 불가
authorizationCode 는 매 인증마다 발급되지만 Apple 이 생략하는 케이스가 있다.
재인증(fresh 로그인)에서 받은 code 는 **5분 내 1회만** 교환 가능 — 받자마자 EF 로
보내야 한다. `WithdrawalCredential(folding:)` 이 nil 이면 `missingCredential` 을
던지므로, 그 경우 revoke 없이 탈퇴 진행(best-effort)으로 폴백한다.

### 시뮬레이터에서 Apple 로그인 무한 스피너
시뮬레이터 설정 → Apple ID 로그인이 안 돼 있으면 발생. 실기기에서 확인.

## 공통

### `unknownProvider` throw
`DefaultAuthService` 조립 시 `providers` 배열에 해당 provider 를 안 넣었다.
provider product 를 SPM 에 추가했는지도 확인 (예: `AuthKitKakao`).

### 로그인은 되는데 REST 요청이 401
SupabaseClient 를 두 개 만들었을 가능성. **앱 전역에 클라이언트는 하나** —
`SupabaseAuthBackend` 에 주입한 것과 같은 인스턴스로 REST 를 호출해야
세션 Bearer 가 실린다.

### 세션이 앱 재시작 후 사라짐
`authEvents` 의 `.initialSessionLoaded` 를 기다리지 않고 `currentIdentity` 를
너무 일찍 읽으면 nil 로 보일 수 있다. 세션 복원은 이벤트 기반으로 처리한다.
