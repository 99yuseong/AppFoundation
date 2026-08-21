//
//  MockNativeAdCachedLoader.swift
//  AppFoundation / AdKit
//
//  Preview·단위 테스트용 SDK 무의존 cache-one 네이티브 로더. 앱 파사드의
//  로드·소비·게이팅 로직을 검증한다 — 렌더링(호스트 바인딩)은 SDK 뷰가
//  필요하므로 mock 범위 밖이다. `Ad` 는 테스트가 임의 타입(String 등)으로
//  바인딩한다.
//

import Combine

@MainActor
public final class MockNativeAdCachedLoader<Ad>: NativeAdCachedLoading {

    @Published private var cachedAd: Ad?

    /// `loadAd()` 가 채울 광고 팩토리. nil 반환 = no-fill (`AdError.noFill` throw).
    public var makeAd: @MainActor () -> Ad?

    /// 로드가 실제로 시도된 횟수 — 테스트 검증용 (캐시 보유 시 no-op 은 미집계).
    public private(set) var loadAttemptCount = 0

    public init(makeAd: @escaping @MainActor () -> Ad? = { nil }) {
        self.makeAd = makeAd
    }

    public var isAdReady: Bool { cachedAd != nil }

    public func loadAd() async throws {
        guard cachedAd == nil else { return }
        loadAttemptCount += 1
        guard let ad = makeAd() else { throw AdError.noFill }
        cachedAd = ad
    }

    public func consumeAd() -> Ad? {
        defer { cachedAd = nil }
        return cachedAd
    }
}
