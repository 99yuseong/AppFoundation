//
//  BannerDemoSection.swift
//  AdSample
//
//  상주 네이티브 배너 (커스텀 레이아웃) 데모 — `AdMobPersistentNativeAdLoader`
//  의 @Published 를 관찰해, 앱이 직접 만든 `DemoBannerAdLayoutView` 를
//  `NativeAdHostView` 에 주입해 표시한다. 로드 전에는 기본(no-fill) 콘텐츠가
//  보인다.
//

import SwiftUI
import AdKitAdMob

struct BannerDemoSection: View {

    @ObservedObject var loader: AdMobPersistentNativeAdLoader

    @State private var status: DemoStatus = .idle

    var body: some View {
        Section {
            NativeAdHostView(ad: loader.shouldShowAd ? loader.currentAd : nil) {
                DemoBannerAdLayoutView()
            }
            .frame(height: 72)
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
            Text("NativeAdLayoutUIView 서브클래스(DemoBannerAdLayoutView)를 NativeAdHostView 에 주입한다.")
        }
    }

    private func load() async {
        status = .loading
        await loader.loadAds()
        status = loader.currentAd != nil ? .success("로드됨") : .failure("no-fill")
    }
}
