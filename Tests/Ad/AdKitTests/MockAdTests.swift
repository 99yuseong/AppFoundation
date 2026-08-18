//
//  MockAdTests.swift
//  AppFoundation / AdKitTests
//
//  Mock 이 전면·보상형 계약의 상태 전이를 올바르게 재현하는지 검증한다 —
//  앱 파사드·프리뷰가 이 Mock 위에서 "광고 준비/소비" 경로를 밟기 때문에
//  계약과 어긋나면 앱 테스트가 통째로 잘못된 전제를 갖게 된다.
//

import Testing
import UIKit
import AdKit

@MainActor
struct MockAdTests {

    @Test("전면: 로드 전 present 는 notReady, 로드 후 present 는 캐시를 소비한다")
    func interstitialLifecycle() async throws {
        let ad = MockInterstitialAdLoader()
        let presenter = UIViewController()

        #expect(ad.isAdReady == false)
        await #expect(throws: AdError.self) {
            try await ad.present(from: presenter)
        }

        await ad.loadAd()
        #expect(ad.isAdReady)

        try await ad.present(from: presenter)
        #expect(ad.isAdReady == false)  // 1회 소비
        #expect(ad.presentCount == 1)
    }

    @Test("보상형: 시청 완료 여부와 SSV userID 전달을 재현한다")
    func rewardedLifecycle() async throws {
        let ad = MockRewardedAdLoader(earnsReward: false)
        let presenter = UIViewController()

        await #expect(throws: AdError.self) {
            _ = try await ad.present(from: presenter, userID: nil)
        }

        await ad.loadAd()
        let earned = try await ad.present(from: presenter, userID: "user-42")
        #expect(earned == false)          // 주입값 그대로
        #expect(ad.lastUserID == "user-42")
        #expect(ad.isAdReady == false)    // 1회 소비
    }

    @Test("네이티브 cache-one: no-fill 은 noFill throw, 캐시 보유 시 no-op, consume 은 1회 소비")
    func nativeCachedLifecycle() async throws {
        let loader = MockNativeAdCachedLoader<String>()

        await #expect(throws: AdError.self) {   // makeAd 기본값 nil = no-fill
            try await loader.loadAd()
        }
        #expect(loader.isAdReady == false)

        loader.makeAd = { "ad-1" }
        try await loader.loadAd()
        #expect(loader.isAdReady)

        try await loader.loadAd()               // 캐시 보유 — 시도 미집계
        #expect(loader.loadAttemptCount == 2)

        #expect(loader.consumeAd() == "ad-1")
        #expect(loader.consumeAd() == nil)      // 1회 소비
        #expect(loader.isAdReady == false)
    }
}
