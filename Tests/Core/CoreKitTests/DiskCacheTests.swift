//
//  DiskCacheTests.swift
//  AppFoundation / CoreKitTests
//
//  DiskCache 의 핵심 정책만 검증한다: TTL 은 저장 시각 기준(읽기로 연장 안 됨),
//  축출은 byteLimit 초과 시 마지막 접근이 오래된 순(LRU). 테스트마다 고유 디렉터리를
//  써서 병렬 실행에 안전하다.
//

import Foundation
import Testing
import CoreKit

@Suite("DiskCache")
struct DiskCacheTests {

    private func makeCache(byteLimit: Int = 0, ttl: Duration? = nil) -> DiskCache {
        DiskCache(name: "DiskCacheTests-\(UUID().uuidString)", byteLimit: byteLimit, ttl: ttl)
    }

    @Test("store → data 왕복 — URL 등 경로 부적합 문자 키도 안전, 키 간 간섭 없음")
    func roundTrip() async {
        let cache = makeCache()
        let keyA = "https://example.com/images/a.png?w=200"
        let keyB = "https://example.com/images/b.png?w=200"

        await cache.store(Data("a".utf8), for: keyA)
        await cache.store(Data("b".utf8), for: keyB)

        #expect(await cache.data(for: keyA) == Data("a".utf8))
        #expect(await cache.data(for: keyB) == Data("b".utf8))
        #expect(await cache.data(for: "https://example.com/images/c.png") == nil)

        await cache.removeAll()
    }

    @Test("TTL — 저장 시각 기준으로 만료되고, 읽기 히트로 연장되지 않는다")
    func ttlExpiry() async throws {
        let cache = makeCache(ttl: .milliseconds(80))
        await cache.store(Data([1]), for: "k")

        // 만료 전 읽기 — 이 접근이 TTL 을 연장하면 안 된다 (접근은 수정일만 갱신).
        #expect(await cache.data(for: "k") != nil)

        try await Task.sleep(for: .milliseconds(150))
        #expect(await cache.data(for: "k") == nil)

        await cache.removeAll()
    }

    @Test("byteLimit 초과 시 마지막 접근이 오래된 항목부터 축출 (LRU)")
    func lruEviction() async throws {
        let cache = makeCache(byteLimit: 250)
        let payload = Data(repeating: 0, count: 100)

        await cache.store(payload, for: "a")
        try await Task.sleep(for: .milliseconds(30))
        await cache.store(payload, for: "b")
        try await Task.sleep(for: .milliseconds(30))

        // a 를 읽어 최근 접근으로 만든다 → 축출 순서상 b 가 가장 오래된 항목이 된다.
        #expect(await cache.data(for: "a") != nil)
        try await Task.sleep(for: .milliseconds(30))

        await cache.store(payload, for: "c")    // 총 300 > 250 → b 축출

        #expect(await cache.data(for: "a") != nil)
        #expect(await cache.data(for: "b") == nil)
        #expect(await cache.data(for: "c") != nil)

        await cache.removeAll()
    }
}
