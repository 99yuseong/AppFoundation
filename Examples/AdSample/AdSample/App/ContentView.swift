//
//  ContentView.swift
//  AdSample
//
//  AdKit·AdKitAdMob 데모 메뉴 — 섹션 하나가 로더 하나의 사용법을 보여준다.
//  각 섹션 구현은 *DemoSection.swift 참고.
//

import SwiftUI

struct ContentView: View {

    @EnvironmentObject private var adCenter: DemoAdCenter

    var body: some View {
        NavigationStack {
            List {
                NativeInterstitialDemoSection(loader: adCenter.nativeInterstitial)
                BannerDemoSection(loader: adCenter.banner)
                InterstitialDemoSection(loader: adCenter.interstitial)
                RewardedDemoSection(loader: adCenter.rewarded)
                ATTDemoSection()
            }
            .navigationTitle("AdSample")
        }
    }
}
