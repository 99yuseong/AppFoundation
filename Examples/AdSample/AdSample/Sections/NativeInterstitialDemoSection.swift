//
//  NativeInterstitialDemoSection.swift
//  AdSample
//
//  전면형 네이티브 (기본 템플릿) 데모 — cache-one 로더를 미리 로드해 두고,
//  같은 캐시를 SwiftUI(fullScreenCover)·UIKit(present) 양쪽으로 표시한다.
//  섹션은 Core 계약(`NativeAdCachedLoading`)에 의존한다 — isAdReady 를 관찰해야
//  하므로 제네릭으로 받는다 (`any` 존재형은 @ObservedObject 불가). 템플릿 뷰가
//  GMA 광고를 소비하므로 `Ad == NativeAd` 제약과 AdKitAdMob import 는 남는다.
//  표시하면 캐시가 소비되므로 상태를 미로드로 되돌린다.
//

import SwiftUI
import GoogleMobileAds
import AdKit
import AdKitAdMob
import CoreKit

struct NativeInterstitialDemoSection<Loader: NativeAdCachedLoading>: View where Loader.Ad == NativeAd {

    @ObservedObject var loader: Loader

    @State private var status: DemoStatus = .idle
    @State private var isPresentingSwiftUI = false

    var body: some View {
        Section {
            DemoStatusRow(title: "상태", status: status)
                .fullScreenCover(isPresented: $isPresentingSwiftUI) {
                    interstitialCover
                }
            Button {
                Task { await load() }
            } label: {
                Label("미리 로드", systemImage: "arrow.down.circle")
            }
            .disabled(status == .loading)
            Button {
                isPresentingSwiftUI = true
            } label: {
                Label("SwiftUI 로 표시 — fullScreenCover", systemImage: "swift")
            }
            .disabled(!loader.isAdReady)
            Button {
                presentWithUIKit()
            } label: {
                Label("UIKit 으로 표시 — present", systemImage: "square.stack")
            }
            .disabled(!loader.isAdReady)
            Button {
                Task { await loadAndPresent() }
            } label: {
                Label("로드 후 즉시 표시", systemImage: "bolt")
            }
            .disabled(status == .loading)
        } header: {
            Label("전면형 네이티브 — 기본 템플릿", systemImage: "rectangle.portrait.inset.filled")
        } footer: {
            Text("AdMobNativeAdInterstitialTemplateUIView + 카운트다운 닫기. SwiftUI 쪽은 하단 커스텀 뷰(setBottomAccessoryView) 주입 예시, UIKit 쪽은 기본(닫기 버튼만). 표시하면 캐시가 소비되어 다시 로드해야 한다.")
        }
    }

    private var interstitialCover: some View {
        AdMobNativeAdInterstitialView(adLoader: loader)
            .setCloseButtonUnlockInterval(3)
            .setBottomAccessoryView { Self.makePromotionButton() }
            .setOnClose {
                isPresentingSwiftUI = false
                status = .idle
            }
            .setOnAdNotReady { isPresentingSwiftUI = false }
            .ignoresSafeArea()
    }

    /// 하단 커스텀 뷰 예시 — 디자인·탭 동작 전부 앱 소유. UIKit 표시 쪽은
    /// 주입하지 않아 기본(닫기 버튼만)이 나온다.
    private static func makePromotionButton() -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = "광고 없이 이용하기 (데모)"
        config.baseBackgroundColor = .white
        config.baseForegroundColor = .black
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 24, bottom: 14, trailing: 24)
        let button = UIButton(configuration: config)
        button.addAction(UIAction { _ in print("promotion tapped") }, for: .touchUpInside)
        return button
    }

    private func load() async {
        status = .loading
        do {
            try await loader.loadAd()
            status = .ready
        } catch {
            status = .failure(demoErrorText(error))
        }
    }

    /// 온디맨드 패턴 — 캐시가 있으면 loadAd() 가 no-op 이라 그대로 즉시 표시된다.
    private func loadAndPresent() async {
        await load()
        guard loader.isAdReady else { return }
        isPresentingSwiftUI = true
    }

    private func presentWithUIKit() {
        let controller = AdMobNativeAdInterstitialViewController(adLoader: loader)
            .setCloseButtonUnlockInterval(3)
            .setOnClose { status = .idle }
        TopMostPresenter.topViewController()?.present(controller, animated: true)
    }
}
