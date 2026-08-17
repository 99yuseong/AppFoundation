//
//  MockInterstitialAd.swift
//  AppFoundation / AdKit
//
//  Preview·단위 테스트용 SDK 무의존 전면 광고. 실제 표시 없이 계약의 상태
//  전이(로드 → 준비 → 소비)만 재현한다.
//

import UIKit

@MainActor
public final class MockInterstitialAd: InterstitialAdControlling {

    public private(set) var isAdReady: Bool = false

    /// 표시된 횟수 — 테스트 검증용.
    public private(set) var presentCount: Int = 0

    public init() {}

    public func loadAd() async {
        isAdReady = true
    }

    public func present(from presenter: UIViewController) async throws {
        guard isAdReady else { throw AdError.notReady }
        isAdReady = false
        presentCount += 1
    }
}
