//
//  SingleFlightCache.swift
//  AppFoundation / AdKit
//
//  값 1개를 로드해 캐시하고(TTL 지원), 중복 로드는 진행 중 작업에 합류시키는
//  single-flight 프리미티브. 앱 소비자용 API 가 아니라 패키지 내부 구현 공유용
//  이라 `package` 접근 수준이며, SDK 없이 단위 테스트하기 위해 Core 에 있다.
//  전면·보상형처럼 "로드해 두었다가 1회 소비" 하는 로더가 쓴다.
//  (캐시 없는 합류만 필요하면 `SingleFlightGate`)
//
//  실패(throw)는 합류자 전원에게 동일하게 전파되고 캐시에 남지 않는다 —
//  다음 호출이 새로 시도한다. MainActor 격리라 상태 변경은 전부 직렬화된다.
//

/// 값 1개 캐시 + 유효기간(TTL) + in-flight 합류.
/// 만료 검사는 `isReady`/`take()` 모든 경계에서 동일하게 적용된다 — 만료된
/// 값은 어느 경로로도 노출되지 않는다.
@MainActor
package final class SingleFlightCache<Value> {

    private var cached: Value?
    private var loadedAt: ContinuousClock.Instant?
    private let cacheDuration: Duration?
    private let clock = ContinuousClock()

    /// 진행 중인 로드 — 중복 호출은 이 작업에 합류한다.
    private var inFlight: Task<Void, Error>?

    /// - Parameter cacheDuration: 캐시 유효기간. nil 이면 만료 없음.
    ///   (광고 SDK 별 만료 정책은 백엔드가 주입한다 — Core 기본값 없음)
    package init(cacheDuration: Duration? = nil) {
        self.cacheDuration = cacheDuration
    }

    package var isReady: Bool {
        removeIfExpired()
        return cached != nil
    }

    /// 캐시가 있으면 즉시 반환(no-op), 없으면 `produce` 를 실행해 채운다.
    /// 이미 로드가 진행 중이면 합류해 같은 결과를 기다린다 — `produce` 가 던진
    /// 에러는 합류자 전원에게 동일하게 전파되고 캐시는 비어 있다.
    package func loadIfNeeded(_ produce: @escaping @MainActor () async throws -> Value) async throws {
        removeIfExpired()
        guard cached == nil else { return }

        if let inFlight {
            try await inFlight.value
            return
        }

        // inFlight 정리는 작업 자신이 종료 직전에 한다 — 최초 호출자의 defer 로
        // 정리하면, 작업 완료 후 합류자가 먼저 깨어나 즉시 재시도할 때 아직
        // 남아 있는 완료된 작업에 다시 합류한다 (이전 결과를 그대로 받는 경합).
        let task = Task {
            defer { self.inFlight = nil }
            let value = try await produce()
            self.cached = value
            self.loadedAt = self.clock.now
        }
        inFlight = task
        try await task.value
    }

    /// 캐시를 1회 소비한다(꺼내면 비워진다). nil = 미보유 또는 만료.
    package func take() -> Value? {
        removeIfExpired()
        defer {
            cached = nil
            loadedAt = nil
        }
        return cached
    }

    package func removeAll() {
        cached = nil
        loadedAt = nil
    }

    private func removeIfExpired() {
        guard cached != nil, let cacheDuration, let loadedAt else { return }
        if clock.now - loadedAt >= cacheDuration {
            cached = nil
            self.loadedAt = nil
        }
    }
}
