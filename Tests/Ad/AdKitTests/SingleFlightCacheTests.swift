//
//  SingleFlightCacheTests.swift
//  AppFoundation / AdKitTests
//
//  보상형 로더의 온디맨드 합류 로직을 SDK 없이 검증한다 — 동시 호출이
//  로드 1회에 합류하는지, 실패(nil)가 캐시를 오염시키지 않고 재시도 가능한지,
//  take 소비 후 재로드가 되는지.
//

import Testing
import AdKit

@MainActor
struct SingleFlightCacheTests {

    @Test("동시 호출은 진행 중 로드 하나에 합류한다 — produce 는 1회만 실행")
    func concurrentCallsJoinSingleLoad() async {
        let cache = SingleFlightCache<Int>()
        var produceCount = 0
        // 어느 쪽이 먼저 스케줄되든 남은 쪽이 합류하도록 같은 produce 를 준다 —
        // 검증 대상은 "실행이 1회뿐"이라는 사실이다.
        let produce: @MainActor () async -> Int? = {
            produceCount += 1
            try? await Task.sleep(for: .milliseconds(50))
            return 7
        }

        async let first: Void = cache.loadIfNeeded(produce)
        async let second: Void = cache.loadIfNeeded(produce)
        _ = await (first, second)

        #expect(produceCount == 1)
        #expect(cache.isReady)
        #expect(cache.take() == 7)
    }

    @Test("실패(nil)는 캐시에 남지 않고 다음 호출이 재시도한다")
    func failureLeavesCacheEmptyAndRetries() async {
        let cache = SingleFlightCache<Int>()
        var produceCount = 0

        await cache.loadIfNeeded {
            produceCount += 1
            return nil  // no-fill/실패
        }
        #expect(cache.isReady == false)
        #expect(cache.take() == nil)

        // in-flight 가 리셋됐으니 재호출은 새로 시도한다.
        await cache.loadIfNeeded {
            produceCount += 1
            return 3
        }
        #expect(produceCount == 2)
        #expect(cache.take() == 3)
    }

    @Test("캐시 보유 중엔 no-op, take 소비 후엔 다시 로드한다")
    func cachedSkipsLoadAndTakeConsumesOnce() async {
        let cache = SingleFlightCache<Int>()
        var produceCount = 0
        let produce: @MainActor () async -> Int? = {
            produceCount += 1
            return produceCount
        }

        await cache.loadIfNeeded(produce)
        await cache.loadIfNeeded(produce)  // 캐시 보유 — 실행 안 됨
        #expect(produceCount == 1)

        #expect(cache.take() == 1)
        #expect(cache.take() == nil)  // 1회 소비

        await cache.loadIfNeeded(produce)  // 소비 후 재로드
        #expect(produceCount == 2)
        #expect(cache.isReady)
    }
}
