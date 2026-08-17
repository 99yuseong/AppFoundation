//
//  NativeAdHostView.swift
//  AppFoundation / AdKitAdMob
//
//  `NativeAdLayoutUIView`(서브클래스)를 SwiftUI 에서 쓰기 위한 범용 래퍼.
//  주입받은 레이아웃을 `NativeAdHostUIView` 로 감싸 트래킹을 연결하고,
//  광고 값 변화(로드/교체/제거)를 레이아웃에 반영한다. 어떤 로더를 쓰든
//  앱이 관찰 중인 광고 값을 그대로 넘기면 된다.
//
//  ```swift
//  NativeAdHostView(ad: adLoader.currentAd) {
//      MyCustomAdLayoutView()   // NativeAdLayoutUIView 서브클래스
//  }
//  ```
//

import SwiftUI
import GoogleMobileAds
import AdKit

public struct NativeAdHostView: UIViewRepresentable {

    private let ad: NativeAd?
    private let makeContentView: @MainActor () -> NativeAdLayoutUIView

    /// - Parameters:
    ///   - ad: 표시할 광고. nil 이면 레이아웃의 기본(no-fill) 콘텐츠가 표시된다.
    ///   - contentView: 광고 레이아웃 팩토리 (`NativeAdLayoutUIView` 서브클래스).
    public init(
        ad: NativeAd?,
        contentView: @escaping @MainActor () -> NativeAdLayoutUIView
    ) {
        self.ad = ad
        self.makeContentView = contentView
    }

    // NativeAdHostUIView 를 그대로 노출하지 않고 UIView 로 감춘다
    public func makeUIView(context: Context) -> UIView {
        NativeAdHostUIView(contentView: makeContentView())
    }

    public func updateUIView(_ uiView: UIView, context: Context) {
        // 광고가 갱신되면 레이아웃에 반영, nil 이면 기본 콘텐츠로 복원
        (uiView as? NativeAdHostUIView)?.configure(with: ad)
    }
}
