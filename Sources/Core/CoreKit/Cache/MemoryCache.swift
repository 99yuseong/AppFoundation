//
//  MemoryCache.swift
//  AppFoundation / CoreKit
//
//  NSCache 를 감싼 제네릭 메모리 캐시. 축출 정책(개수/비용 상한, 메모리 압박 시
//  자동 비움)은 전부 NSCache 에 위임한다 — 이 타입의 역할은 클래스 키·값만 받는
//  NSCache 를 String 키 + 임의 값 타입으로 쓰게 하는 어댑터가 전부다.
//
//  `Cache` 프로토콜 추상화는 일부러 두지 않는다 — 교체 수요가 생기기 전의
//  추상화는 API 도메인의 "과도한 추상화 금지" 원칙과 같은 이유로 배제한다.
//

import Foundation

public final class MemoryCache<Value: Sendable>: @unchecked Sendable {
    // @unchecked 근거: 유일한 상태인 NSCache 가 스레드 세이프, Box 는 불변.

    /// NSCache 는 클래스 키·값만 받는다 — 값 타입 Value 를 감싸는 상자.
    private final class Box {
        let value: Value
        init(_ value: Value) { self.value = value }
    }

    private let cache = NSCache<NSString, Box>()

    /// - Parameters:
    ///   - countLimit: 항목 개수 상한. 0 이면 무제한 (NSCache 기본).
    ///   - totalCostLimit: `store(_:for:cost:)` 로 전달한 cost 합계 상한 (바이트 등
    ///     호출자가 정한 단위). 0 이면 무제한.
    public init(countLimit: Int = 0, totalCostLimit: Int = 0) {
        cache.countLimit = countLimit
        cache.totalCostLimit = totalCostLimit
    }

    public func value(for key: String) -> Value? {
        cache.object(forKey: key as NSString)?.value
    }

    public func store(_ value: Value, for key: String, cost: Int = 0) {
        cache.setObject(Box(value), forKey: key as NSString, cost: cost)
    }

    public func removeValue(for key: String) {
        cache.removeObject(forKey: key as NSString)
    }

    public func removeAll() {
        cache.removeAllObjects()
    }
}
