//
//  InterstitialAdLoading.swift
//  AppFoundation / AdKit
//
//  전면 광고 백엔드 계약. 백엔드(AdKitAdMob 등)의 로더가 채택하고, 앱 파사드·
//  프리뷰·테스트는 이 계약(또는 Mock/)에만 의존한다.
//

import UIKit

/// 전면 광고: 미리 로드해 두었다가(cache-one) 전체 화면으로 표시한다.
@MainActor
public protocol InterstitialAdLoading {

    /// 로드된 광고가 표시 가능 상태인가.
    var isAdReady: Bool { get }

    /// 광고 1개를 미리 로드한다. 이미 캐시가 있으면 no-op.
    /// no-fill 은 `AdError.noFill`, 그 외 실패는 `AdError.loadFailed` 를 던진다.
    func loadAd() async throws

    /// 캐시된 광고를 표시하고 닫힐 때 반환된다.
    /// 로드된 광고가 없으면 `AdError.notReady`, 다른 광고 표시 중이면
    /// `AdError.alreadyPresenting`(캐시 미소비), 표시 시작 실패는
    /// `AdError.presentationFailed` 를 던진다.
    func present(from presenter: UIViewController) async throws
}
