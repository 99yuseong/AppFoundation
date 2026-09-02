//
//  SignedURLCacheTests.swift
//  AppFoundation / APIKitTests
//
//  서명 URL 재사용 캐시의 핵심 로직 — 만료 판정(80% 창)과 키 분리.
//  시계는 주입식이라 실시간 대기 없이 경계를 검증한다.
//

import Foundation
import Testing
@testable import APIKit

@Suite("SignedURLCache")
struct SignedURLCacheTests {

    /// 테스트 고정 시계.
    private final class Clock: @unchecked Sendable {
        private let lock = NSLock()
        private var _now = Date(timeIntervalSince1970: 0)
        var now: Date {
            get { lock.withLock { _now } }
            set { lock.withLock { _now = newValue } }
        }
    }

    @Test("만료 80% 이전에는 재사용, 도달하면 미스")
    func reuseWindow() {
        let clock = Clock()
        let cache = SignedURLCache(now: { clock.now })
        let url = URL(string: "https://cdn.example.com/a.jpg?token=1")!

        cache.store(url, forBucket: "b", path: "u1/a.jpg", expiresIn: 100)

        clock.now = Date(timeIntervalSince1970: 79)
        #expect(cache.url(forBucket: "b", path: "u1/a.jpg") == url)

        clock.now = Date(timeIntervalSince1970: 80)   // 100초 × 0.8 경계 — 재발급 대상
        #expect(cache.url(forBucket: "b", path: "u1/a.jpg") == nil)
    }

    @Test("버킷·경로가 하나라도 다르면 다른 키")
    func keyIsolation() {
        let clock = Clock()
        let cache = SignedURLCache(now: { clock.now })
        let url = URL(string: "https://cdn.example.com/a.jpg?token=1")!

        cache.store(url, forBucket: "b1", path: "p1", expiresIn: 100)

        #expect(cache.url(forBucket: "b1", path: "p1") == url)
        #expect(cache.url(forBucket: "b2", path: "p1") == nil)
        #expect(cache.url(forBucket: "b1", path: "p2") == nil)
    }

    @Test("만료 후 재저장하면 새 URL 로 다시 재사용")
    func refreshAfterExpiry() {
        let clock = Clock()
        let cache = SignedURLCache(now: { clock.now })
        let first = URL(string: "https://cdn.example.com/a.jpg?token=1")!
        let second = URL(string: "https://cdn.example.com/a.jpg?token=2")!

        cache.store(first, forBucket: "b", path: "p", expiresIn: 100)
        clock.now = Date(timeIntervalSince1970: 90)
        #expect(cache.url(forBucket: "b", path: "p") == nil)

        cache.store(second, forBucket: "b", path: "p", expiresIn: 100)
        #expect(cache.url(forBucket: "b", path: "p") == second)
    }
}
