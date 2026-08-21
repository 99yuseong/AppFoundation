//
//  DemoAdCenter.swift
//  AdSample
//
//  데모용 광고 조립(composition root) — AdMob 구체 로더를 만드는 곳은 여기
//  하나뿐이다. 섹션 뷰들은 Core 계약(`~AdLoading`/`NativeAd~Loading`)으로
//  주입받으므로, 다른 백엔드로 바꾸려면 이 파일의 생성부만 교체하면 된다.
//  실제 앱에서는 이 역할을 앱의 로컬 AdKit 패키지(placement 파사드)가 맡는다.
//  로더는 전부 placement-generic 이라 unit ID 만 주입하면 된다.
//

import SwiftUI
import Combine
import AdKit
import AdKitAdMob

@MainActor
final class DemoAdCenter: ObservableObject {

    /// 전면형 네이티브 (기본 템플릿 데모). video 테스트 unit 은 no-fill 이 잦아
    /// 일반 네이티브 unit 을 쓴다 — 영상 크리에이티브를 보려면
    /// `DemoAdUnitID.nativeAdvancedVideo` 로 바꾼다.
    let nativeInterstitial = AdMobNativeAdCachedLoader(
        adUnitId: DemoAdUnitID.nativeAdvanced
    )

    /// 상주 네이티브 배너 (커스텀 레이아웃 데모).
    let banner = AdMobNativeAdPersistentLoader(
        adUnitId: DemoAdUnitID.nativeAdvanced,
        configuration: .init(cacheDuration: nil)
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
