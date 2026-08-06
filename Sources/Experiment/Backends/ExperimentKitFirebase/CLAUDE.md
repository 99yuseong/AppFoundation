# ExperimentKitFirebase

`ExperimentClient` 의 Firebase Remote Config 어댑터. Firebase A/B Testing 이
Remote Config 에 배정한 값을 제공한다. `FirebaseRemoteConfig` SDK 소유 →
별도 product (product 분리 원칙).

## 공개 API

- `FirebaseExperimentClient` — `RemoteConfig` 인스턴스 + 초기 defaults 주입.
  앱은 `FirebaseApp.configure()` 이후에 생성해야 한다.

## 설계 결정 (변경 전에 읽을 것)

- fetch policy 매핑: `.cached` → expiration `greatestFiniteMagnitude`(사실상 fetch
  안 함), `.expiration(d)` → `max(0, d)`, `.fresh` → 0.
- fetch 가 `.success` 가 아니거나 activate 가 false 면 `.usingCachedValue` 반환 —
  실패를 던지지 않고 기존 값 유지가 기본 동작.
- 값 읽기는 `configValue(forKey:).stringValue` 경로만 사용 — 타입 변환은 전부
  `ExperimentKey.decode`(ExperimentKit) 소관. 단 **`.static` 소스(원격·defaults
  어디에도 없는 키)는 어댑터가 defaultValue 로 폴백**한다 — Firebase 가 빈 문자열을
  반환해 String 키의 기본값이 무시되는 것을 막는다.
- `setDefaults` 는 전체 교체 API 라 **defaults 가 비어 있으면 호출하지 않는다** —
  앱이 다른 경로로 등록한 defaults 를 지우지 않기 위해서다.
