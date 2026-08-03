# ExperimentKit

실험(A/B)·원격 설정 계약 계층. 외부 SDK 무의존.

## 공개 API

- `ExperimentClient` — 백엔드 계약 protocol. `fetchAndActivate(policy:)` 로 원격값을
  갱신하고, `value(for:)` 로 타입 안전하게 읽는다.
- `ExperimentKey<Value>` — 원격 문자열 → 앱 타입 변환 키. `name` + `defaultValue` +
  decode 클로저. `RawRepresentable(String)` enum 은 전용 이니셜라이저, String/Bool/
  Int/Double 은 기본 decode 제공.
- `ExperimentFetchPolicy` — `.cached`(캐시만) / `.expiration(TimeInterval)` /
  `.fresh`(즉시 갱신).
- `InMemoryExperimentClient` — Preview·단위 테스트용 SDK 무의존 구현체.

## 설계 결정 (변경 전에 읽을 것)

- **원격값은 항상 문자열로 취급**하고 `ExperimentKey.decode` 가 타입 변환을 소유한다.
  변환 실패·값 없음은 예외가 아니라 **defaultValue 폴백** — 원격 설정 오타가 앱을
  깨뜨리지 않는다.
- 키는 닫힌 enum 이 아니라 값 타입 — 앱이 kit 수정 없이 자체 키를 정의한다
  (개방형 provider 원칙과 동일).
- `value(for:)` 는 동기·논스로잉 — 읽기 시점에 네트워크를 타지 않는다. 갱신은
  `fetchAndActivate` 가 전담한다 (fetch 와 read 의 분리).
