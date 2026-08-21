//
//  MockRewardedAdLoader.swift
//  AppFoundation / AdKit
//
//  Preview·단위 테스트용 SDK 무의존 보상형 광고. 시청 완료 여부는 주입값으로
//  제어한다 (기본 true = 항상 끝까지 시청).
//

import UIKit

@MainActor
public final class MockRewardedAdLoader: RewardedAdLoading {

    public private(set) var isAdReady: Bool = false

    /// present 가 돌려줄 시청 완료 여부.
    public var earnsReward: Bool

    /// 마지막 present 에 전달된 SSV 사용자 식별자 — 테스트 검증용.
    public private(set) var lastUserID: String?

    public init(earnsReward: Bool = true) {
        self.earnsReward = earnsReward
    }

    public func loadAd() async {
        isAdReady = true
    }

    public func present(from presenter: UIViewController, userID: String?) async throws -> Bool {
        guard isAdReady else { throw AdError.notReady }
        isAdReady = false
        lastUserID = userID
        return earnsReward
    }
}
