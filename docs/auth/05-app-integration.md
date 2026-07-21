# 05. 앱 통합

## 1. SPM 추가

Xcode: **File → Add Package Dependencies** → `git@github.com:{계정}/AppFoundation.git`
(private repo 는 SSH 권장 — Xcode 계정에 SSH 키 등록 필요)

**앱 타겟에는 사용하는 product 만 추가한다:**

| 앱 구성 | 추가할 product |
|---|---|
| Apple + Kakao (예: TumTumRead) | `AuthKit`, `AuthKitSupabase`, `AuthKitKakao` (+`CoreKit`) |
| Apple + Google (예: Doran) | `AuthKit`, `AuthKitSupabase`, `AuthKitGoogle` (+`CoreKit`) |

### 로컬 개발 오버라이드

kit 자체를 수정하며 개발할 때는 **로컬 클론 폴더를 앱 workspace 에 드래그**하면
Xcode 가 같은 이름의 원격 패키지를 로컬로 자동 오버라이드한다. 드래그를 빼면
원격으로 복귀.

## 2. 설정 키 (xcconfig → Info.plist)

Secret.xcconfig 등에 키를 넣고 Info.plist 에 `$(KEY)` 로 연결한다:

| 키 | 값 | 필요 조건 |
|---|---|---|
| `SUPABASE_PROJECT_ID` | 프로젝트 서브도메인 | 항상 |
| `SUPABASE_API_KEY` | anon public key | 항상 |
| `KAKAO_APP_KEY` | 네이티브 앱 키 | Kakao 사용 시 |
| `GOOGLE_CLIENT_ID` | iOS Client ID | Google 사용 시 |

## 3. Info.plist — URL scheme 등 (개발자가 Xcode에서)

- **Kakao**: URL Types 에 scheme `kakao{네이티브앱키}` 추가,
  `LSApplicationQueriesSchemes` 에 `kakaokompassauth`, `kakaolink` 추가
- **Google**: URL Types 에 reversed client ID
  (`com.googleusercontent.apps.xxxx`) 추가
- **Apple**: Signing & Capabilities 에 **Sign in with Apple** capability 추가

## 4. 조립 코드

```swift
import AuthKit
import AuthKitSupabase
import AuthKitKakao   // 사용하는 provider 만
import CoreKit
import Supabase

// 앱 전역 SupabaseClient 는 하나만 — 이미 있으면 그걸 주입한다.
let supabaseURL = URL(string: "https://\(ConfigValues.require("SUPABASE_PROJECT_ID")).supabase.co")!
let supabaseKey = ConfigValues.require("SUPABASE_API_KEY")
let client = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseKey)

let authService: any AuthService = DefaultAuthService(
    backend: SupabaseAuthBackend(
        client: client,
        configuration: .init(supabaseURL: supabaseURL, apiKey: supabaseKey)
    ),
    providers: [
        AppleAuthProvider(),
        KakaoAuthProvider(),
        // GoogleAuthProvider(clientID: ConfigValues.require("GOOGLE_CLIENT_ID")),
    ]
)
```

앱 launch 시 (Kakao 사용 시):

```swift
KakaoAuthProvider.initialize(appKey: ConfigValues.require("KAKAO_APP_KEY"))
```

## 5. OAuth 콜백 연결

```swift
// SwiftUI
.onOpenURL { url in
    _ = authService.handle(url)
}

// UIKit AppDelegate
func application(_ app: UIApplication, open url: URL,
                 options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    authService.handle(url)
}
```

## 6. 사용

```swift
// 로그인 (SwiftUI 라면 presenter 에 TopMostPresenter 활용)
let result = try await authService.signIn(
    with: .kakao,
    presenter: { TopMostPresenter.topViewController() ?? UIViewController() }
)
// result.identity   → uid/provider/email
// result.credential → Apple authorizationCode 등 로그인 직후에만 얻는 값

// 세션 관찰 (자동 로그인, 세션 무효화 감지)
for await (event, identity) in authService.authEvents {
    switch event {
    case .initialSessionLoaded, .signedIn: // identity 반영
    case .signedOut, .userDeleted:         // 로그아웃 상태로
    case .tokenRefreshed: break
    }
}

// REST 호출용 토큰
let token = await authService.accessToken

// 탈퇴 (표준 흐름 — 06 참조)
let credential = try await authService.reauthenticate(provider: provider, presenter: presenter)
let withdrawal = try WithdrawalCredential(folding: credential)
// → account-withdraw EF 호출 → authService.endSession()
```

## 7. 취소 처리

사용자가 로그인 시트를 닫으면 `AuthKitError.cancelled` 가 던져진다.
`error.isCancelled` 이면 보통 에러 UI 없이 조용히 넘어간다.
