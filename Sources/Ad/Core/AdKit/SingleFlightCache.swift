//
//  SingleFlightCache.swift
//  AppFoundation / AdKit
//
//  온디맨드 단일 캐시 + in-flight 합류(single flight). 동시 로드 요청(더블 탭
//  등)이 진행 중인 작업 하나에 합류해 같은 결과를 기다리고, 실패(nil)는 캐시에
//  남기지 않아 다음 호출이 그대로 재시도한다. 백엔드 로더가 SDK 로드에 쓰는
//  합류 로직을 SDK 없이 단위 테스트하기 위해 분리했다. MainActor 격리라
//  상태 변경은 전부 한 액터에서 직렬화된다.
//

@MainActor
public final class SingleFlightCache<Value> {

    public private(set) var cached: Value?
    /// 진행 중인 로드 — 중복 호출은 이 작업에 합류한다.
    private var inFlight: Task<Void, Never>?

    public init() {}

    /// 캐시가 있으면 즉시 반환(no-op), 없으면 `produce` 를 실행해 채운다.
    /// 이미 로드가 진행 중이면 합류해 그 결과를 기다린다. `produce` 가 nil 을
    /// 돌려주면(실패) 캐시는 비어 있고 다음 호출이 새로 시도한다.
    /// (`produce` 는 캐시와 같은 MainActor 격리 — globally-isolated 클로저라
    /// 동시 합류 호출에도 Sendable 하다.)
    public func loadIfNeeded(_ produce: @escaping @MainActor () async -> Value?) async {
        guard cached == nil else { return }
        if let inFlight {
            await inFlight.value
            return
        }
        let task = Task {
            cached = await produce()
        }
        inFlight = task
        await task.value
        inFlight = nil
    }

    public var isReady: Bool { cached != nil }

    /// 캐시를 1회 소비한다(꺼내면 비워진다). nil = 미보유.
    public func take() -> Value? {
        defer { cached = nil }
        return cached
    }
}
