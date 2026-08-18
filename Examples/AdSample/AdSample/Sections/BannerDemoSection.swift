//
//  BannerDemoSection.swift
//  AdSample
//
//  상주 네이티브 배너 (커스텀 레이아웃) 데모 — 로더의 @Published 를 관찰해,
//  앱이 직접 만든 `DemoBannerAdLayoutView` 를 `AdMobNativeAdHostView` 에 주입해
//  표시한다. 섹션은 Core 계약(`NativeAdPersistentLoading`)에 의존한다 —
//  게시 값을 관찰해야 하므로 존재형이 아니라 제네릭으로 받는다
//  (`any` 존재형은 @ObservedObject 불가). 호스트가 GMA 광고 객체를 바인딩하므로
//  `Ad == NativeAd` 제약과 AdKitAdMob import 는 남는다.
//

import SwiftUI
import GoogleMobileAds
import AdKit
import AdKitAdMob

struct BannerDemoSection<Loader: NativeAdPersistentLoading>: View where Loader.Ad == NativeAd {

    @ObservedObject var loader: Loader

    @State private var status: DemoStatus = .idle

    var body: some View {
        Section {
            // shouldShowAd == false 는 "숨김" — 슬롯 자체를 제거한다.
            // (host 에 nil 을 넘기는 것은 숨김이 아니라 기본(no-fill) 콘텐츠 표시다.)
            if loader.shouldShowAd {
                AdMobNativeAdHostView(ad: loader.currentAd) {
                    DemoBannerAdLayoutView()
                }
                .frame(height: 72)
            }
            DemoStatusRow(title: "상태", status: status)
            Button {
                Task { await load() }
            } label: {
                Label("배너 로드", systemImage: "arrow.down.circle")
            }
            .disabled(status == .loading)
        } header: {
            Label("상주 네이티브 배너 — 커스텀 레이아웃", systemImage: "rectangle.bottomthird.inset.filled")
        } footer: {
            Text("NativeAdLayoutUIView 서브클래스(DemoBannerAdLayoutView)를 AdMobNativeAdHostView 에 주입한다.")
        }
    }

    private func load() async {
        status = .loading
        do {
            try await loader.loadAd()
            status = loader.currentAd != nil ? .success("로드됨") : .idle
        } catch {
            status = .failure(demoErrorText(error))
        }
    }
}
