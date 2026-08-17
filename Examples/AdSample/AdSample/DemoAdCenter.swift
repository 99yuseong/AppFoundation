//
//  DemoAdCenter.swift
//  AdSample
//
//  데모용 광고 조립 — 실제 앱에서는 이 역할을 앱의 로컬 AdKit 패키지
//  (placement 파사드)가 맡는다. 로더는 전부 placement-generic 이라 unit ID 만
//  주입하면 된다.
//

import Foundation
import AdKit
import AdKitAdMob

@MainActor
final class DemoAdCenter: ObservableObject {

    /// 전면형 네이티브 (기본 템플릿 데모) — 영상 크리에이티브가 나오는 테스트 unit.
    let nativeInterstitial = AdMobCachedNativeAdLoader(
        adUnitId: DemoAdUnitID.nativeAdvancedVideo
    )

    /// 상주 네이티브 배너 (커스텀 레이아웃 데모).
    let banner = AdMobPersistentNativeAdLoader(
        adUnitId: DemoAdUnitID.nativeAdvanced,
        configuration: PersistentNativeAdConfiguration(cacheDuration: nil)
    )

    /// SDK 전면 광고.
    let interstitial = AdMobInterstitialAdLoader(adUnitId: DemoAdUnitID.interstitial)

    /// 보상형 광고 (SSV 없이 — userID nil).
    let rewarded = AdMobRewardedAdLoader(adUnitId: DemoAdUnitID.rewarded)

    @Published private(set) var isSDKStarted = false

    /// GMA SDK 시작 (1회). 테스트 unit ID 만 쓰므로 테스트 기기 등록은 생략.
    func startIfNeeded() async {
        guard !isSDKStarted else { return }
        await AdMobConfigurator().configure()
        isSDKStarted = true
    }
}
