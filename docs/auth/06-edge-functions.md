# 06. Edge Functions — 회원탈퇴

App Store 심사 지침 5.1.1(v): 계정 생성이 있으면 앱 내 계정 삭제를 제공해야 하고,
Sign in with Apple 사용 시 탈퇴 때 Apple 토큰 revoke 가 의무다.

## 표준: 재인증형 하이브리드 (`account-withdraw`)

이 repo 의 [`supabase/functions/account-withdraw`](../../supabase/functions/account-withdraw/index.ts)
템플릿을 그대로 배포한다.

| provider | 전략 |
|---|---|
| Apple | 탈퇴 직전 **재인증** → fresh authorizationCode → 서버가 토큰 교환 후 즉석 revoke |
| Google | 탈퇴 직전 **재인증** → fresh access token → 서버가 revoke 엔드포인트 호출 |
| Kakao | **admin key 서버 unlink** — 클라이언트 credential 불필요 (identities 에서 user id 조회) |

장점: 서버에 장기 자격증명(refresh token)을 보관하지 않는다. 로그인 경로에 서버
의존이 없어 revoke 커버리지 구멍도 없다. 비용: 탈퇴 시 로그인 팝업 1회 (탈퇴는
저빈도 이벤트라 UX 비용이 낮다). 사용자가 재인증을 거부하면 **credential 없이
호출해 revoke 는 skip 하고 탈퇴는 진행**한다 (best-effort).

### 배포

```bash
# 템플릿 복사 (앱 서버 repo 의 supabase/functions/ 아래로)
cp -r AppFoundation/supabase/functions/account-withdraw supabase/functions/

# secrets 등록 (01 문서 참조)
supabase secrets set APPLE_TEAM_ID=… APPLE_CLIENT_ID=… APPLE_KEY_ID=… \
  APPLE_PRIVATE_KEY="$(cat AuthKey_XXXX.p8)" KAKAO_ADMIN_KEY=…

supabase functions deploy account-withdraw
```

### 클라이언트 호출

```swift
func withdraw(provider: SocialProvider, presenter: AuthPresenter?) async throws {
    // 1. 재인증 (거부/실패 시 credential 없이 진행 = revoke skip)
    var body: [String: Any] = [:]
    if let credential = try? await authService.reauthenticate(provider: provider, presenter: presenter),
       let withdrawal = try? WithdrawalCredential(folding: credential) {
        switch withdrawal {
        case let .apple(code):   body["credential"] = ["provider": "apple", "authorizationCode": code]
        case let .google(token): body["credential"] = ["provider": "google", "token": token]
        case .kakao:             break // 서버가 admin key 로 처리 — 전송 불필요
        }
    }

    // 2. EF 호출 (supabase-swift functions.invoke 또는 URLSession)
    try await client.functions.invoke("account-withdraw", options: .init(body: body))

    // 3. 로컬 정리
    await authService.endSession()
}
```

## 대안: 서버 보관형 (TumTumRead 방식) — 참고용

로그인 시점에 `SignInResult.credential` 의 Apple authorizationCode 를 EF
(`apple-store-refresh-token` 류)로 보내 서버가 refresh token 을 영구 보관하고,
탈퇴 시 재로그인 없이 서버가 보관 토큰으로 revoke 하는 방식.

- 장점: 탈퇴 UX 에 로그인 팝업이 없다
- 단점: 자격증명 저장 테이블·보안 관리 필요, **로그인 시점 저장이 실패한 사용자는
  나중에 revoke 불가** (커버리지 구멍), 로그인 경로에 서버 호출 추가

AuthKit 은 이 방식도 지원한다 — `SignInResult.credential` 이 로그인 직후의
authorizationCode 를 그대로 노출하므로, 앱이 자체 EF 로 보내면 된다. 서버 구현은
앱 소유 (kit 은 템플릿을 제공하지 않는다).

## 참고: Kakao target_id 를 클라이언트에서 구해야 할 때

표준 템플릿은 서버가 auth identities 에서 kakao user id 를 찾으므로 불필요하지만,
기존 EF (TumTumRead `kakao-unlink` 류)가 target_id 를 요구하면 idToken 의 `sub`
claim 에서 꺼낸다:

```swift
func kakaoSub(fromIdToken idToken: String) -> String? {
    let segments = idToken.split(separator: ".")
    guard segments.count == 3 else { return nil }
    var base64 = String(segments[1]).replacingOccurrences(of: "-", with: "+")
        .replacingOccurrences(of: "_", with: "/")
    base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
    guard let data = Data(base64Encoded: base64),
          let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return nil }
    return payload["sub"] as? String
}
```
