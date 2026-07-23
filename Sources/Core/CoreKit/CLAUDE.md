# CoreKit

도메인 무관 최소 기반. 어떤 도메인(Auth/Purchase/…)도 모른 채 모든 kit 과 앱이
공유하는 유틸리티만 담는다.

## 공개 API

- `ConfigValues` — Info.plist 설정 로더 (`require(_:)` / `optional(_:)`)
- `TopMostPresenter` — 최상단 뷰컨트롤러 탐색 (SwiftUI 에서 presenter 공급용)
- `Cache/` — 제네릭 캐시 프리미티브. `MemoryCache`(NSCache 어댑터) +
  `DiskCache`(Caches/ 하위, TTL·byteLimit LRU). `Cache` 프로토콜 추상화는 두지 않는다.

## 여기 넣지 말 것

- 도메인 로직(Auth/Purchase/…) — 해당 도메인 타겟으로
- 외부 SDK 의존 — CoreKit 은 시스템 프레임워크만 의존한다
- UI 컴포넌트 — 도메인 소속이면 해당 kit, 범용 디자인 시스템은 별도 타겟으로

## 규칙

- 모든 kit 이 이 타겟에 의존하므로 API 변경은 전체 breaking — 가장 보수적으로.
