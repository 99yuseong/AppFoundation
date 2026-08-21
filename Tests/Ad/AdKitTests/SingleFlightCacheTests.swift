//
//  SingleFlightCacheTests.swift
//  AppFoundation / AdKitTests
//
//  백엔드 로더의 합류·TTL 로직을 SDK 없이 검증한다 — 동시 호출이 로드 1회에
//  합류하는지, 실패가 합류자 전원에게 전파되고 캐시를 오염시키지 않는지,
//  만료가 isReady/take 모든 경계에서 적용되는지.
//

import Testing
import AdKit

@MainActor
struct SingleFlightCacheTests {

    @Test("동시 호출은 진행 중 로드 하나에 합류한다 — produce 는 1회만 실행")
    func concurrentCallsJoinSingleLoad() async throws {
        let cache = SingleFlightCache<Int>()
        var produceCount = 0
        let produce: @MainActor () async throws -> Int = {
            produceCount += 1
            try? await Task.sleep(for: .milliseconds(50))
            return 7
        }

        async let first: Void = cache.loadIfNeeded(produce)
        async let second: Void = cache.loadIfNeeded(produce)
        _ = try await (first, second)

        #expect(produceCount == 1)
        #expect(cache.isReady)
        #expect(cache.take() == 7)
    }

    @Test("실패는 합류자 전원에게 전파되고 캐시에 남지 않는다 — 다음 호출이 재시도")
    func failurePropagatesToJoinersAndRetries() async throws {
        struct LoadFailure: Error {}
        let cache = SingleFlightCache<Int>()
        var produceCount = 0
        let failing: @MainActor () async throws -> Int = {
            produceCount += 1
            try? await Task.sleep(for: .milliseconds(50))
            throw LoadFailure()
        }

        // 동시 합류 — 양쪽 모두 같은 에러를 받는다.
        async let first: Void = cache.loadIfNeeded(failing)
        async let second: Void = cache.loadIfNeeded(failing)
        var errorCount = 0
        do { try await first } catch { errorCount += 1 }
        do { try await second } catch { errorCount += 1 }

        #expect(errorCount == 2)
        #expect(produceCount == 1)
        #expect(cache.isReady == false)
        #expect(cache.take() == nil)

        // in-flight 가 리셋됐으니 재호출은 새로 시도한다.
        try await cache.loadIfNeeded {
            produceCount += 1
            return 3
        }
        #expect(produceCount == 2)
        #expect(cache.take() == 3)
    }

    @Test("캐시 보유 중엔 no-op, take 소비 후엔 다시 로드한다")
    func cachedSkipsLoadAndTakeConsumesOnce() async throws {
        let cache = SingleFlightCache<Int>()
        var produceCount = 0
        let produce: @MainActor () async throws -> Int = {
            produceCount += 1
            return produceCount
        }

        try await cache.loadIfNeeded(produce)
        try await cache.loadIfNeeded(produce)  // 캐시 보유 — 실행 안 됨
        #expect(produceCount == 1)

        #expect(cache.take() == 1)
        #expect(cache.take() == nil)  // 1회 소비

        try await cache.loadIfNeeded(produce)  // 소비 후 재로드
        #expect(produceCount == 2)
        #expect(cache.isReady)
    }

    @Test("만료는 isReady/take 모든 경계에서 적용되고, 만료 후 로드는 새로 시도한다")
    func expiryAppliesAtEveryBoundary() async throws {
        let cache = SingleFlightCache<Int>(cacheDuration: .milliseconds(40))
        var produceCount = 0
        let produce: @MainActor () async throws -> Int = {
            produceCount += 1
            return produceCount
        }

        try await cache.loadIfNeeded(produce)
        #expect(cache.isReady)

        try await Task.sleep(for: .milliseconds(60))
        #expect(cache.isReady == false)   // 만료 — isReady 경계
        #expect(cache.take() == nil)      // 만료 — take 경계

        try await cache.loadIfNeeded(produce)   // 만료 후 재로드
        #expect(produceCount == 2)
        #expect(cache.take() == 2)
    }

    @Test("실패 직후 합류자의 즉시 재시도는 완료된 이전 작업에 재합류하지 않는다")
    func joinerImmediateRetryStartsFreshAttempt() async {
        struct LoadFailure: Error {}
        let cache = SingleFlightCache<Int>()
        var produceCount = 0
        let failing: @MainActor () async throws -> Int = {
            produceCount += 1
            try? await Task.sleep(for: .milliseconds(30))
            throw LoadFailure()
        }

        // 합류자가 최초 호출자보다 먼저 깨어나 즉시 재시도해도, 완료된 이전
        // 작업이 inFlight 에 남아 있으면 안 된다 (남으면 재합류해 1회에 그친다).
        async let first: Void = cache.loadIfNeeded(failing)
        async let joinerThenRetry: Void = {
            try? await cache.loadIfNeeded(failing)
            try? await cache.loadIfNeeded(failing)   // 즉시 재시도 — 새 시도여야 함
        }()
        _ = try? await first
        _ = await joinerThenRetry

        #expect(produceCount == 2)
    }

    @Test("SingleFlightGate: 동시 호출 합류 + 에러 동일 전파")
    func gateJoinsAndPropagatesErrors() async throws {
        struct WorkFailure: Error {}
        let gate = SingleFlightGate()
        var workCount = 0

        // 합류 — work 1회만 실행.
        let work: @MainActor () async throws -> Void = {
            workCount += 1
            try? await Task.sleep(for: .milliseconds(50))
        }
        async let first: Void = gate.run(work)
        async let second: Void = gate.run(work)
        _ = try await (first, second)
        #expect(workCount == 1)

        // 에러 — 합류자 전원에게 전파.
        async let third: Void = gate.run {
            try? await Task.sleep(for: .milliseconds(50))
            throw WorkFailure()
        }
        async let fourth: Void = gate.run { }
        var errorCount = 0
        do { try await third } catch { errorCount += 1 }
        do { try await fourth } catch { errorCount += 1 }
        #expect(errorCount == 2)
    }
}
