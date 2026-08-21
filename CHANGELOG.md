# Changelog

## 0.8.0 (unreleased — feature/ad-kit)

### 추가 — Ad 도메인 (TumTumRead AdFeature + Doran AdKit 통합 이식)
- `AdKit` (신규 도메인 `Sources/Ad/`, SDK 무의존): 로더 계약
  (`InterstitialAdLoading`/`RewardedAdLoading` + associatedtype 기반
  `NativeAdLoading`/`NativeAdCachedLoading`/`NativeAdPersistentLoading`/
  `NativeAdRotatingLoading`), 백엔드 중립 네이티브 레이아웃
  (`NativeAdLayoutUIView`+`NativeAdContent`), `AdConditionChecker`,
  `ATTAuthorization`, `AdError`, Mock 3종
- `AdKitAdMob`: GMA 13.x 실행 — placement-generic 로더 6종
  (단발/캐시/상주/로테이션 네이티브, 전면·보상형+SSV, TTL·single-flight 합류·
  상태 가드 내장), `AdMobNativeAdHost(UI)View`, 전면형 네이티브 기본 템플릿
  (카운트다운 닫기 + `setBottomAccessoryView` 커스텀 슬롯, UIKit/SwiftUI 쌍)
- `Examples/AdSample` 데모 앱 (Google 테스트 unit, 계약 주입 구조)
- 외부 의존 추가: `swift-package-manager-google-mobile-ads` from 13.5.0
- 컨벤션 신설: 1 타입 1 파일 + 서브도메인 폴더링, 백엔드 public 타입
  `{백엔드}{광고 단위}{기능}` 네이밍, `AGENTS.md`(=CLAUDE.md 심볼릭 링크)
  — 기존 13개 모듈에도 소급 적용

### 변경(호환 깨짐) — 브랜치 내 API 확정 리네임 (0.x minor = breaking)
- 이 도메인은 0.8.0 이 첫 공개라 외부 마이그레이션 대상은 없지만, 브랜치
  중간 커밋 대비 이름이 바뀌었다: `~Controlling` → `~Loading`
  (`InterstitialAdControlling` 등), `AdMobCachedNativeAdLoader` →
  `AdMobNativeAdCachedLoader`(Persistent/Rotating 동일 어순), `NativeAdHost~` →
  `AdMobNativeAdHost~`, `NativeAdInterstitial~`(VC/View/Template) →
  `AdMobNativeAdInterstitial~`, `MockInterstitialAd`/`MockRewardedAd` →
  `Mock~AdLoader`, Configuration 3종 → 각 로더 nested `Configuration`
  (`Configuration()` == `.default`), Persistent `loadAds()` → `loadAd()`,
  Rotating `observeCondition()` → `start()`/`stop()`,
  `shouldRemoveAds` → `shouldShowAd`, 콜백 빌더 `setOnClose` 통일,
  `loadAd()` 는 throwing (`AdError.noFill`/`.loadFailed`), present 에
  `.alreadyPresenting`/`.presentationFailed` 추가

## 0.7.0 (2026-08-04)

### 추가 — Experiment 도메인 (TumTumRead 에서 이식)
- `ExperimentKit` (신규 도메인 `Sources/Experiment/`): 실험(A/B)·원격 설정 계약 계층,
  SDK 무의존
  - `ExperimentClient` — `fetchAndActivate(policy:)` / `value(for:)` 백엔드 계약
  - `ExperimentKey<Value>` — 원격 문자열 → 앱 타입 변환 키. 변환 실패·값 없음은
    defaultValue 폴백. `RawRepresentable(String)` enum + String/Bool/Int/Double 기본 제공
  - `InMemoryExperimentClient` — Preview·단위 테스트용 구현체
- `ExperimentKitFirebase`: Firebase Remote Config 어댑터 (`FirebaseRemoteConfig` 소유
  → 별도 product). Firebase A/B Testing 배정값 제공
- 외부 의존 추가: `firebase-ios-sdk` from 12.1.0 (하한 = TumTumRead 현재 pin)

## 0.6.0 (2026-07-25)

### 변경(호환 깨짐) — `mapServerError` 훅이 `(code, message, details)` 로
- 훅 시그니처가 늘었다. 2인자 훅을 넘기던 호출부는 컴파일이 깨지므로 아래 둘 중
  하나로 옮긴다: ① 3인자로 고치기 ② `withSimpleErrorMapping(...)` 팩토리 쓰기.
  0.x 대라 minor 를 올린다(0.x 의 minor = breaking).

### 추가 — 실패 응답 부가 필드 전달 (`ServerErrorDetails`)
- `APIKit`: `ServerErrorDetails` 신설 — 실패 본문에서 `code`/`message` **밖의 필드**를
  앱까지 전달한다. 서버가 error 객체에 재시도 대상 id 같은 값을 함께 싣는 계약을
  쓸 때, 그 값이 매핑 경계에서 버려지던 것을 막는다.
  `decode(_:)`(앱 타입으로) / `string(forKey:)`(문자열 지름길) 두 진입.
  **kit 은 내용을 해석하지 않는다** — 어떤 키가 오는지는 앱·서버 계약이므로
  `mapServerError` 훅이 꺼내 쓴다("앱 전용 코드를 `APIError` 케이스로 승격하지
  않는다"와 같은 규칙).
- `mapServerError` 훅 시그니처가 `(code, message, details)` 로 늘었다.
  `details` 는 EF/REST 의 `{ok:false,error}` 본문에서만 채워지고,
  **RPC(PostgrestError)는 구조화된 본문이 없어 항상 nil** 이다.
- `(code, message)` 훅만 쓰던 호출부는 `SupabaseAPIClient.withSimpleErrorMapping(...)` /
  `RESTAPIClient.withSimpleErrorMapping(...)` 팩토리로 옮긴다.
  생성자 오버로드로 두지 않은 이유는 클로저 인자 수만 다른 오버로드가
  `self.init` 을 자기 자신으로 해소해 **무한 재귀**가 되기 때문이다.

## 0.5.0 (2026-07-23)

### 추가 — 캐시 · REST 백엔드 · Image 도메인
- `CoreKit/Cache`: 제네릭 캐시 프리미티브 — `MemoryCache`(NSCache 어댑터, String
  키 + 임의 값 타입) + `DiskCache`(actor, SHA256 파일명, 저장 시각 기준 TTL,
  byteLimit 초과 시 마지막 접근 오래된 순 LRU 축출)
- `APIKitREST`: `RESTAPIClient` — `APIClient` 의 URLSession 실구현 (의존 zero 라
  `APIKit` 타깃에 포함, AuthKitREST 선례). `EndpointTransport.http` 신설 —
  `Endpoint.name` = path, 선언 메타데이터였던 `method` 가 처음 실제 전송 verb 로
  쓰인다. `unwrapping: .raw`(기본)/`.envelope`(자기 서버 계약 opt-in), `adapt`
  훅(토큰 주입), `mapServerError` 훅(Supabase 백엔드와 대칭). `stream` 은 v1 미지원
- `ImageKit` (신규 도메인 `Sources/Image/`): 원격 이미지 파이프라인 + 비동기 뷰 쌍
  - `ImageLoader` — 메모리(다운샘플 결과) → 디스크(원본 Data) → URLSession.
    같은 URL 동시 요청은 다운로드 1회 공유(dedup) + 진행률 멀티캐스트, 재시도 내장
  - `ImageDownsampler` — ImageIO 썸네일 경로 (풀 디코드 없이 메모리 피크 억제)
  - `RemoteImage`(SwiftUI) / `RemoteUIImage`(UIKit) — set~ 빌더 컨벤션,
    Kingfisher 모디파이어군 참고: placeholder·failureImage·onProgress·fade
    (디스크/네트워크 로드만, 메모리 히트는 즉시 표시)·onSuccess/onFailure·retry·
    maxPixelSize·forceRefresh·cancelOnDisappear(+UIKit 인디케이터)

## 0.4.0 (2026-07-23)

### 추가 — API 도메인 (Doran-iOS APIClient 이식)
- `APIKit`: 서버 API 계약 계층 (SDK 무의존) — `APIClient`(`request`/`stream` 단일
  진입), `Endpoint`(`name`·`transport`·`method`·`task` 선언 메타데이터, Moya
  TargetType 참고), 개방형 `EndpointTransport`/`HTTPMethod`, `EndpointTask`
  (`.plain`/`.json`/`.query`/`.upload`), 중립 `APIError` + `{ok,data}` envelope,
  `EndpointKey`, `MockAPIClient`(EndpointKey 별 JSON 주입 + 호출 순서 기록)
- `APIKitSupabase`: `SupabaseAPIClient` — EF(`functions.invoke` + envelope 해체) /
  RPC(배열-first 디코드) / DB·Storage·Realtime(엔드포인트가 SDK 직접 실행) 라우팅,
  `mapServerError` 훅(앱 도메인 에러 매핑), `DatabaseEndpoint`/`StorageEndpoint`/
  `RealtimeEndpoint` + Context, `SupabaseTable`/`SupabaseBucket`,
  `SupabaseSessionUserIDProvider`
- `docs/api/00-overview.md`: 비용 원칙(EF 호출 제한 → 클라 조합)·선언 관례·서버
  확장 마이그레이션 스토리·SupabaseClient 공유 규칙

### 출처
Doran-iOS 의 검증된 APIClient/Supabase 시스템을 일반화·이식 (앱 전용 에러 코드는
훅으로 분리, Realtime 구독·method/task 선언 메타데이터는 신규 설계).

## 0.3.0 (2026-07-21)

### 추가
- `RESTAuthBackend`: 일반(자체) 서버용 백엔드 (외부 의존 zero라 `AuthKit` 에 내장) —
  표준 REST 계약 (`docs/auth/08-custom-backend.md`), `RESTSession`, `SessionStoring`
  (Keychain 기본/InMemory), 계약이 다른 서버용 encode/decode 오버라이드
- 개방형 provider: `AuthCredential.custom(provider:parameters:)` /
  `WithdrawalCredential.custom` — 앱 정의 provider 를 kit 수정 없이 추가
- provider 소유 브랜딩: `AuthProvider.branding`(기본값 내장 + 생성자 주입),
  `SocialLoginBranding`/`SocialLoginOption`, `AuthService.loginOptions`
  (주입 순서 = 노출 순서)
- `SocialLoginButtonStack`(SwiftUI) / `SocialLoginUIButtonStack`(UIKit) —
  `loginOptions` 를 받아 등록된 provider 만 노출
- `SocialLoginBranding.Logo.image`/`.asset(_:)` — 이미지 에셋 로고 지원
- 각 모듈 최상단 + 루트 `CLAUDE.md` — 모듈 책임·경계·컨벤션 명시
- `docs/auth/08-custom-backend.md` — 자체 서버 계약(서버 id_token 검증 포함),
  `AuthBackend` 직접 구현, 커스텀 provider 확장 가이드

### 변경 (breaking)
- `AppleAuthProvider` 를 `AuthKitApple` product 로 분리 — provider 는 전부
  `AuthKit{Provider}` 대칭 규칙. 사용 앱은 `AuthKitApple` product 추가 +
  `import AuthKitApple` 필요
- `SocialProvider`: enum → String 기반 struct (`CaseIterable` 제거 — 등록 목록은
  `AuthService.loginOptions` 가 대체)
- 로그인 버튼: `setProvider`/`setAppleStyle` 제거 — `SocialLoginOption` 주입으로
  대체 (`SocialLoginButton(option:action:)`, Apple 스타일은
  `AppleAuthProvider(branding: .apple(.whiteOutline))`)
- `AuthProvider` 에 `branding` 요구사항 추가 — 직접 구현한 provider 는 branding
  프로퍼티를 추가해야 함
- 기본 로고 교체: Google 은 공식 에셋(Doran DesignGuide 이식), Kakao 는 SF Symbol
  `message.fill`(TumTumRead 와 동일). 이에 따라 `SocialLoginLogo` 의
  `googleSegments`/`kakaoBubblePath`(CGPath 근사)와 4색 상수 제거
- 디렉토리 재편: `Sources/Auth/{Core,Providers,Backends}/` (폴더 이동만 — API 불변)
- `AuthKitREST` product 제거 — `AuthKit` 타깃에 흡수(product 7 → 6).
  `RESTAuthBackend` 는 이제 `import AuthKit` 으로 쓴다.
  **타깃 분리 기준은 계층이 아니라 외부 SDK 경계** — 의존성 없는 `Core/AuthKit` 과
  `Backends/AuthKitREST` 를 한 타깃으로 묶었다(폴더는 계층대로 유지)

## 0.2.0 (2026-07-21)

### 추가
- `SocialLoginButton` (SwiftUI) / `SocialLoginUIButton` (UIKit): 소셜 로그인 버튼 —
  `setProvider` 로 브랜드 전환(apple/google/kakao), `set~` 빌더 모디파이어
  (`setCornerRadius`/`setHeight`/`setIsLoading` 바인딩/`setAppleStyle`/`setOnTap`/`setLoading`)
- 로고 CGPath 공유 정의(`SocialLoginLogo`) — Kakao 말풍선, Google 4색 G (SwiftUI·UIKit 재사용)
- Localization: ko / en / ja (`Localizable.xcstrings`, `defaultLocalization: ko`)
- `Examples/AuthSample`: 데모 앱 (SwiftUI/UIKit 탭, Mock 기본, LiveAuthAssembly 실연결 예시)

## 0.1.0 (2026-07-21)

첫 릴리스 — Auth 도메인.

### 추가
- `CoreKit`: `ConfigValues`(Info.plist 설정 로더), `TopMostPresenter`
- `AuthKit`: 코어 타입(`SocialProvider`/`AuthIdentity`/`AuthEvent`/`AuthCredential`/
  `SignInResult`/`WithdrawalCredential`/`SignOutScope`/`AuthKitError`),
  프로토콜(`AuthProvider`/`AuthBackend`/`AuthService`), `DefaultAuthService`,
  `NonceGenerator`, `AppleAuthProvider`, `MockAuthService`
- `AuthKitGoogle`: `GoogleAuthProvider` (GIDSignIn)
- `AuthKitKakao`: `KakaoAuthProvider` (KakaoSDK 네이티브 + OIDC)
- `AuthKitSupabase`: `SupabaseAuthBackend`, Kakao GoTrue REST id_token grant 격리
  (`KakaoIdTokenGrant` — supabase-swift 가 kakao 지원 시 삭제)
- `supabase/functions/account-withdraw`: 회원탈퇴 표준 EF 템플릿 (재인증형 하이브리드)
- `docs/auth/00~07`: 콘솔 설정 순서·앱 통합·탈퇴·트러블슈팅 가이드
- `.claude/skills/auth-setup`: 신규 앱 통합 안내 스킬

### 출처
TumTumRead(Apple/Kakao)와 Doran(Apple/Google)의 검증된 Auth 구현을 통합·이식.
