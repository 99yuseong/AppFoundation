# ImageKit

원격 이미지 파이프라인 + 비동기 이미지 뷰. 외부 SDK 무의존 (의존: CoreKit 캐시).

## 공개 API

- `ImageLoader` — actor 파이프라인: 메모리(URL+크기 → 다운샘플 UIImage) →
  디스크(URL → **원본 인코딩 Data**) → URLSession. 같은 URL 동시 요청은 다운로드
  하나를 공유(dedup)하고 진행률을 대기자 전원에 멀티캐스트. 재시도는 로더 소관.
- `ImageDownsampler` — ImageIO 썸네일 경로 다운샘플링 (풀 디코드 없이 메모리 피크 억제).
- `RemoteImage` / `RemoteUIImage` — SwiftUI/UIKit 쌍 컴포넌트 (set~ 빌더 컨벤션).
  Kingfisher 모디파이어군 참고: placeholder·failureImage·onProgress·fade·onSuccess/
  onFailure·retry·maxPixelSize·forceRefresh·cancelOnDisappear(+UIKit 인디케이터).

## 설계 결정 (변경 전에 읽을 것)

- **URLSession 직결 — APIKit 미경유.** 이미지 fetch 는 바이트 파이프라인이라
  `request<Decodable>` 의 JSON/envelope 의미론과 맞지 않고, 이미지만 원하는 앱에
  계약 계층을 강제하지 않는다. 인증 헤더가 필요하면 전용 URLSession 을 주입한다.
- **캐시 2단 구성**: 디스크는 원본 Data (다른 크기 요청 시 재다운로드 없이 재다운샘플),
  메모리는 다운샘플 결과 (키에 크기 포함).
- **페이드는 디스크/네트워크 로드에만** — 메모리 히트는 즉시 표시 (스크롤 깜빡임 방지).
  `ImageLoadResult.source` 가 이 판단의 근거다.
- 디코드·다운샘플은 `@concurrent` 경로 — 로더 actor·메인 액터를 잡지 않는다.
- 대기자 취소는 공유 다운로드를 멈추지 않는다 — 받은 데이터는 캐시를 데운다.
- 보류 (수요 증명 시): progressive JPEG, low-data-mode 대체 소스, 프로세서 체인, prefetch.
