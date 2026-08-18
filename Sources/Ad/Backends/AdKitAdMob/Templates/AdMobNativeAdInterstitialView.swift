//
//  AdMobNativeAdInterstitialView.swift
//  AppFoundation / AdKitAdMob
//
//  `AdMobNativeAdInterstitialViewController` 의 SwiftUI 쌍. `fullScreenCover` 안에
//  넣고, 닫기는 콜백에서 앱이 자기 상태(binding)를 끄는 것으로 처리한다 —
//  VC 가 스스로 dismiss 하지 않아 SwiftUI 프레젠테이션 상태와 어긋나지 않는다.
//
//  ```swift
//  .fullScreenCover(isPresented: $isShowingAd) {
//      AdMobNativeAdInterstitialView(adLoader: loader)
//          .setCloseButtonUnlockInterval(5)
//          .setOnClose { isShowingAd = false }
//          .ignoresSafeArea()
//  }
//  ```
//

import SwiftUI
import GoogleMobileAds
import AdKit

public struct AdMobNativeAdInterstitialView: UIViewControllerRepresentable {

    private let adLoader: any NativeAdCachedLoading<NativeAd>
    private var closeButtonUnlockInterval: TimeInterval = 5
    private var showsDefaultContentWhenAdMissing = false
    private var makeContentView: (@MainActor () -> NativeAdLayoutUIView)?
    private var makeBottomAccessoryView: (@MainActor () -> UIView)?
    private var onClose: (() -> Void)?
    private var onAdNotReady: (() -> Void)?

    public init(adLoader: any NativeAdCachedLoading<NativeAd>) {
        self.adLoader = adLoader
    }

    // MARK: - set~ 빌더

    /// 닫기 버튼이 활성화될 때까지의 카운트다운(초). 0 이하 = 즉시 활성.
    public func setCloseButtonUnlockInterval(_ interval: TimeInterval) -> Self {
        var copy = self
        copy.closeButtonUnlockInterval = interval
        return copy
    }

    /// 닫기 버튼 위에 배치할 커스텀 뷰 팩토리 (구독 유도 CTA 등). 미설정 =
    /// 닫기 버튼만. 탭 액션 등 동작은 뷰를 만든 앱이 소유한다.
    public func setBottomAccessoryView(_ make: @escaping @MainActor () -> UIView) -> Self {
        var copy = self
        copy.makeBottomAccessoryView = make
        return copy
    }

    /// 광고 카드 디자인 팩토리. 기본은 `AdMobNativeAdInterstitialTemplateUIView`.
    public func setAdContentView(_ contentView: @escaping @MainActor () -> NativeAdLayoutUIView) -> Self {
        var copy = self
        copy.makeContentView = contentView
        return copy
    }

    /// true 면 광고 미준비 시 기본 콘텐츠를 표시한다 (기본: `onAdNotReady` 호출).
    public func setShowsDefaultContentWhenAdMissing(_ shows: Bool) -> Self {
        var copy = self
        copy.showsDefaultContentWhenAdMissing = shows
        return copy
    }

    /// 닫기 버튼 탭 콜백 — 여기서 프레젠테이션 상태(binding)를 끈다.
    public func setOnClose(_ action: @escaping () -> Void) -> Self {
        var copy = self
        copy.onClose = action
        return copy
    }

    /// 표시 시점에 로드된 광고가 없을 때 콜백 — 보통 여기서도 상태를 끈다.
    public func setOnAdNotReady(_ action: @escaping () -> Void) -> Self {
        var copy = self
        copy.onAdNotReady = action
        return copy
    }

    // MARK: - UIViewControllerRepresentable

    public func makeUIViewController(context: Context) -> AdMobNativeAdInterstitialViewController {
        let controller = AdMobNativeAdInterstitialViewController(adLoader: adLoader)
            .setCloseButtonUnlockInterval(closeButtonUnlockInterval)
            .setShowsDefaultContentWhenAdMissing(showsDefaultContentWhenAdMissing)
        if let makeContentView {
            controller.setAdContentView(makeContentView())
        }
        if let makeBottomAccessoryView {
            controller.setBottomAccessoryView(makeBottomAccessoryView())
        }
        // dismiss 는 앱 상태가 소유한다 — VC 는 콜백만 쏜다.
        controller.dismissesOnCloseTap = false
        controller
            .setOnClose(onClose)
            .setOnAdNotReady(onAdNotReady)
        return controller
    }

    public func updateUIViewController(_ uiViewController: AdMobNativeAdInterstitialViewController, context: Context) {
        // 광고 소비형 단발 화면 — 생성 시점 설정으로 고정된다.
    }
}
