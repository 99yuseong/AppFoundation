# Changelog

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
