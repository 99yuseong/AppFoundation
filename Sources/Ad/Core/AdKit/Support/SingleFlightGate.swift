//
//  SingleFlightGate.swift
//  AppFoundation / AdKit
//
//  캐시 없는 로드 합류 게이트 — 결과를 자체 상태(@Published 등)로 게시하는
//  delegate 기반 로더가 중복 로드만 합류시킬 때 쓴다 (값 캐시까지 필요하면
//  `SingleFlightCache`). `package` 접근 — 패키지 내부 구현 공유용.
//

/// 첫 호출이 작업을 만들고, 진행 중 중복 호출은 그 작업에 합류해 같은
/// 완료(에러 포함)를 기다린다. 결과 게시는 호출부 소유.
@MainActor
package final class SingleFlightGate {

    private var inFlight: Task<Void, Error>?

    package init() {}

    package func run(_ work: @escaping @MainActor () async throws -> Void) async throws {
        if let inFlight {
            try await inFlight.value
            return
        }
        // inFlight 정리는 작업 자신이 종료 직전에 한다 — 호출자 defer 로 정리하면
        // 완료 후 합류자가 먼저 깨어나 즉시 재시도할 때 완료된 작업에 다시 합류한다.
        let task = Task {
            defer { self.inFlight = nil }
            try await work()
        }
        inFlight = task
        try await task.value
    }
}
