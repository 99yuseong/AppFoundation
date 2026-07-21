# AuthSample

AppFoundation **AuthKit** 데모 앱 — `SocialLoginButton`(SwiftUI) / `SocialLoginUIButton`(UIKit)
과 로그인 플로우를 보여준다.

## 실행

`AuthSample.xcodeproj` 를 열고 시뮬레이터에서 Run. 기본은 **MockAuthService** 라
콘솔 설정 없이 바로 동작한다 (버튼 UI·isLoading·cornerRadius 데모 목적).

- **SwiftUI 탭**: `SocialLoginButton` — `setProvider` 3종, `setIsLoading($isLoading)`
  바인딩, `setCornerRadius` 슬라이더 실시간 반영
- **UIKit 탭**: `SocialLoginUIButton` — `set~` 체이닝, `setLoading(_:)` 상태 전환

버튼 문구는 ko / en / ja 로컬라이제이션 — 시뮬레이터 언어를 바꾸면 확인 가능.

## 실서비스(Supabase) 연결

`LiveAuthAssembly.swift` 상단 주석의 5단계를 따른다. 요약:

1. [docs/auth/00-overview.md](../../docs/auth/00-overview.md) 체크리스트로 콘솔 설정
2. 앱 타겟에 `Supabase` product 추가
3. Info.plist 키(`SUPABASE_PROJECT_ID` 등) + URL scheme (Kakao `kakao{키}`, Google reversed client ID)
4. Active Compilation Conditions 에 `LIVE_AUTH` 추가
5. `AuthSampleApp.auth` 를 `LiveAuthAssembly.makeLiveAuthService()` 로 교체
6. (Apple 로그인) Signing & Capabilities 에서 **Sign in with Apple** capability 추가 — 개발자가 Xcode 에서

## 구조

```
AuthSample/
├── AuthSampleApp.swift          # 조립 + onOpenURL 연결
├── LoginView.swift              # SwiftUI 버튼 데모
├── UIKitLoginViewController.swift  # UIKit 버튼 데모
└── LiveAuthAssembly.swift       # 실서비스 조립 예시 (#if LIVE_AUTH)
```
