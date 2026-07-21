# 08. 커스텀 백엔드·커스텀 provider

Auth 는 3계층으로 나뉘어 어느 조합으로도 갈아끼울 수 있다:

```
AuthProvider (credential 획득)     AuthBackend (credential ↔ 세션 교환)
  AuthKitApple / Google / Kakao      AuthKitSupabase   — Supabase
  + 앱 정의 provider                 AuthKitREST       — 일반(자체) 서버
                                     (직접 구현)        — Firebase 등
              └── DefaultAuthService (오케스트레이터) ──┘
```

## 1. 일반 서버 — `AuthKitREST`

자체 API 서버로 소셜 로그인을 처리하는 앱은 `AuthKitSupabase` 대신 `AuthKitREST`
product 를 추가한다. 외부 의존이 없다.

### 조립

```swift
import AuthKit
import AuthKitREST

let authService: any AuthService = DefaultAuthService(
    backend: RESTAuthBackend(
        configuration: .init(
            exchangeURL: URL(string: "https://api.example.com/auth/exchange")!,
            signOutURL: URL(string: "https://api.example.com/auth/signout")!,  // 없으면 생략
            additionalHeaders: ["x-api-key": apiKey]
        )
    ),
    providers: [AppleAuthProvider(), KakaoAuthProvider()]
)
```

세션은 기본으로 Keychain(`KeychainSessionStore`)에 저장된다. 테스트/프리뷰는
`InMemorySessionStore` 를 주입한다.

### 표준 계약 (앱 서버가 구현할 스펙)

**교환** — `POST {exchangeURL}`

```jsonc
// 요청 (Content-Type: application/json)
{
  "provider": "apple" | "google" | "kakao" | "...",
  "id_token": "...",         // apple/kakao/google
  "nonce": "...",            // apple/kakao — raw nonce (아래 검증 참조)
  "access_token": "..."      // google
}
// .custom credential 은 parameters 가 body 에 그대로 병합된다

// 응답 (2xx)
{
  "access_token": "...",     // 이후 Bearer 로 쓰일 앱 서버 토큰
  "refresh_token": "...",    // 선택
  "uid": "...",              // 서버가 확정한 사용자 식별자
  "email": "..."             // 선택
}
```

**로그아웃** — `POST {signOutURL}` (설정 시)

```jsonc
// 헤더: Authorization: Bearer <access_token>
{ "scope": "local" | "global" }
```

### 서버의 id_token 검증 (필수)

서버는 받은 `id_token` 을 반드시 검증한다:

1. **서명**: provider JWKS 로 검증
   - Apple: `https://appleid.apple.com/auth/keys`
   - Google: `https://www.googleapis.com/oauth2/v3/certs`
   - Kakao: `https://kauth.kakao.com/.well-known/jwks.json`
2. **aud**: 앱의 client ID(Apple: bundle ID, Google: client ID, Kakao: 네이티브 앱 키)
3. **iss / exp**: 발급자·만료 확인
4. **nonce** (apple/kakao): id_token 의 `nonce` claim == **SHA256(요청 body 의 `nonce`)**
   — 클라이언트가 SDK 에 해시를 주고 서버에 raw 를 보내는 구도다.
   Google 은 nonce 를 쓰지 않는다.

검증 후 `sub` claim 으로 사용자를 찾거나 만들고 자체 토큰을 발급한다.

### 계약이 다른 서버

기존 서버 스펙을 못 바꾸면 encode/decode 만 오버라이드한다:

```swift
RESTAuthBackend(configuration: .init(
    exchangeURL: url,
    encodeExchangeBody: { credential in
        try JSONEncoder().encode(MyServerRequest(credential))
    },
    decodeExchangeResponse: { data in
        let dto = try JSONDecoder().decode(MyServerResponse.self, from: data)
        return RESTSession(accessToken: dto.token, uid: dto.userID, email: dto.email)
    }
))
```

### 범위 주의

`RESTAuthBackend` 는 **access token 자동 갱신을 하지 않는다**. 짧은 만료의 토큰을
쓰는 서버라면 아래처럼 `AuthBackend` 를 직접 구현한다.

## 2. `AuthBackend` 직접 구현 (Firebase 등)

프로토콜 하나만 구현하면 provider 와 `DefaultAuthService` 는 그대로 재사용된다:

```swift
public protocol AuthBackend: Sendable {
    var currentIdentity: AuthIdentity? { get async }
    var events: AsyncStream<(event: AuthEvent, identity: AuthIdentity?)> { get }
    func exchange(_ credential: AuthCredential) async throws -> AuthIdentity
    func signOut(scope: SignOutScope) async throws
    var accessToken: String? { get async }
}
```

구현 지침:
- `exchange` 는 credential 을 자기 방식(Firebase 라면 `signIn(with: OAuthCredential)`)
  으로 교환하고, 에러는 `AuthKitError`(backendHTTP/backendNetwork 등)로 매핑한다.
- `events` 는 백엔드 SDK 의 상태 스트림을 `AuthEvent` 로 번역한다 — 앱 실행 시
  세션 복원은 `.initialSessionLoaded` 로 드러낸다.

## 3. 커스텀 provider (예: naver)

kit 수정 없이 새 소셜 로그인을 추가한다:

```swift
// ① provider 식별자 정의 (열린 struct)
extension SocialProvider {
    static let naver = SocialProvider(rawValue: "naver")
}

// ② 브랜딩 값 생성 (버튼 디자인은 provider 소유)
extension SocialLoginBranding {
    static let naver = SocialLoginBranding(
        title: String(localized: "네이버로 로그인"),
        foreground: .white,
        background: UIColor(red: 0.01, green: 0.78, blue: 0.35, alpha: 1),
        logo: .sfSymbol("n.square.fill")
    )
}

// ③ AuthProvider 구현
struct NaverAuthProvider: AuthProvider {
    let type: SocialProvider = .naver
    let branding: SocialLoginBranding

    init(branding: SocialLoginBranding = .naver) { self.branding = branding }

    @MainActor
    func authenticate(presenter: AuthPresenter?) async throws -> AuthCredential {
        // Naver SDK 왕복 후:
        .custom(provider: .naver, parameters: ["id_token": idToken])
    }
}

// ④ 조립 배열에 추가 — 버튼·서비스 코드 수정 없이 노출된다
DefaultAuthService(backend: restBackend, providers: [
    AppleAuthProvider(),
    NaverAuthProvider(),
])
```

`.custom` credential 은 `RESTAuthBackend` 가 parameters 를 계약 body 에 병합해
보낸다. `SupabaseAuthBackend` 는 kit 이 아는 provider 만 지원하므로
`unknownProvider` 를 던진다 — 커스텀 provider 는 자체 서버 또는 직접 구현 백엔드와
조합한다.
