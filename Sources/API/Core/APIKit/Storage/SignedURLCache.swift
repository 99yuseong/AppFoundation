//
//  SignedURLCache.swift
//  AppFoundation / APIKit
//
//  서명 URL 재사용 캐시 — 만료 전 재발급 요청을 없앤다. private 오브젝트는 표시
//  1회 = 서명 1요청이 기본이라, 재사용 없이는 서명 경로(R2 는 Worker 무료 한도
//  10만 req/일)가 먼저 바닥난다. 만료의 80% 까지만 재사용해, 발급받은 URL 이
//  사용 시점에 이미 죽어 있는 경계를 피한다.
//
//  축출은 CoreKit MemoryCache(NSCache)에 위임하고, 이 타입은 만료 판정만 얹는다.
//  동시 미스의 중복 발급은 막지 않는다 — 서명은 왕복 1회짜리 소액 연산이라
//  dedup 이 이득을 증명하기 전엔 들이지 않는다 (ImageLoader 와 다른 판단인 이유).
//

import Foundation
import CoreKit

public final class SignedURLCache: @unchecked Sendable {
    // @unchecked 근거: 유일한 상태인 MemoryCache 가 스레드 세이프(NSCache 위임), Entry 불변.

    private struct Entry: Sendable {
        let url: URL
        let refreshAfter: Date
    }

    private let cache: MemoryCache<Entry>
    private let now: @Sendable () -> Date

    /// 만료 대비 재사용 상한 비율. 0.8 = 만료 20% 전부터는 새로 발급.
    private static let reuseRatio = 0.8

    /// - Parameters:
    ///   - countLimit: 캐시 항목 상한 (기본 512 — 목록 화면 수 페이지 분량).
    ///   - now: 현재 시각 제공자. 테스트에서 고정 시계를 주입한다.
    public init(countLimit: Int = 512, now: @escaping @Sendable () -> Date = { Date() }) {
        self.cache = MemoryCache(countLimit: countLimit)
        self.now = now
    }

    /// 재사용 가능한 서명 URL. 만료(80%)가 지났으면 제거하고 nil — 호출부는 재발급 후 store.
    public func url(forBucket bucketName: String, path: String) -> URL? {
        let key = Self.key(bucketName, path)
        guard let entry = cache.value(for: key) else { return nil }
        guard now() < entry.refreshAfter else {
            cache.removeValue(for: key)
            return nil
        }
        return entry.url
    }

    /// 발급받은 서명 URL 을 저장한다. `expiresIn` 은 발급 시 쓴 만료(초).
    public func store(_ url: URL, forBucket bucketName: String, path: String, expiresIn: TimeInterval) {
        let entry = Entry(url: url, refreshAfter: now().addingTimeInterval(expiresIn * Self.reuseRatio))
        cache.store(entry, for: Self.key(bucketName, path))
    }

    public func removeAll() {
        cache.removeAll()
    }

    private static func key(_ bucketName: String, _ path: String) -> String {
        "\(bucketName)/\(path)"
    }
}
