//
//  NativeAdHostUIView.swift
//  AppFoundation / AdKitAdMob
//
//  주입받은 `NativeAdLayoutUIView`(레이아웃)를 감싸 GMA 트래킹을 연결하는
//  `NativeAdView` 셸.
//
//  - 레이아웃을 자신에게 꽉 채워 배치하고, 레이아웃이 노출한 asset 뷰들을 GMA 에 등록한다.
//  - 레이아웃의 미디어/AdChoices 컨테이너에 SDK 뷰를 꽉 채워 삽입한다 — 레이아웃은
//    자리만 잡고 SDK 타입을 모른다. 미디어 표시 방식은 컨테이너의 `contentMode` 를 따른다.
//  - `configure(with:)` 에 nil 을 넘기면 기본 콘텐츠(no-fill 상태)로 전환한다.
//  - 디자인은 전적으로 레이아웃이 소유하므로, 이 클래스는 앱별 커스텀 없이 재사용된다.
//

import UIKit
import GoogleMobileAds
import AdKit

@MainActor
public final class NativeAdHostUIView: NativeAdView {

    // MARK: - Properties

    private let content: NativeAdLayoutUIView
    private let gmaMediaView = MediaView()
    private let gmaAdChoicesView = AdChoicesView()

    /// 현재 바인딩된 광고 — 같은 광고 재바인딩(no-op)과 새 광고 교체(재등록)를 구분한다.
    private weak var boundAd: NativeAd?
    private var isShowingDefaultContent = false

    // MARK: - Initialization

    public init(contentView: NativeAdLayoutUIView) {
        self.content = contentView
        super.init(frame: .zero)

        // 자신의 translatesAutoresizingMaskIntoConstraints 는 건드리지 않는다 —
        // SwiftUI(UIViewRepresentable)는 frame 으로 직접 사이징하므로 끄면
        // 내부 제약의 압축 크기로 좌상단에 붙는다. UIKit 에서 제약으로 배치할
        // 때는 배치하는 쪽이 끈다 (표준 관례).
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)

        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: topAnchor),
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
            content.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        embedSDKViews()
        registerAssetViews()
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public Methods

    /// 광고 데이터를 레이아웃에 반영하고 트래킹을 연결한다. nil 이면 기본
    /// 콘텐츠로 전환한다. 같은 광고를 다시 넘기면 no-op (SwiftUI update 대응).
    public func configure(with nativeAd: NativeAd?) {
        guard let nativeAd else {
            configureDefaultContent()
            return
        }
        guard nativeAd !== boundAd else { return }
        boundAd = nativeAd
        isShowingDefaultContent = false

        // MediaView 가 검은 화면으로 남지 않도록 mediaContent 를 명시적으로 바인딩
        gmaMediaView.mediaContent = nativeAd.mediaContent

        content.configure(with: NativeAdContent(nativeAd: nativeAd))

        // GMA 권장 순서: 에셋 뷰 구성 완료 후 마지막에 nativeAd 를 연결
        self.nativeAd = nativeAd
    }

    /// 기본 콘텐츠(no-fill 상태)로 전환하고 트래킹을 해제한다.
    public func configureDefaultContent() {
        guard !isShowingDefaultContent else { return }
        isShowingDefaultContent = true
        boundAd = nil
        nativeAd = nil
        content.configureDefaultContent()
    }

    // MARK: - Touch Handling

    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)

        // 레이아웃이 터치를 통과시킨 영역(hitTest nil)은 호스트도 통과시킨다
        if result === self,
           !content.usesWholeViewAsClickTarget,
           content.passesThroughTouchesOutsideContent {
            return nil
        }

        return result
    }

    // MARK: - Private Methods

    /// 레이아웃이 자리만 잡아둔 컨테이너에 SDK 뷰를 꽉 채워 삽입한다.
    private func embedSDKViews() {
        if let container = content.adMediaContainerView {
            gmaMediaView.contentMode = container.contentMode
            gmaMediaView.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(gmaMediaView)
            NSLayoutConstraint.activate([
                gmaMediaView.topAnchor.constraint(equalTo: container.topAnchor),
                gmaMediaView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                gmaMediaView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                gmaMediaView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])
        }
        if let container = content.adChoicesContainerView {
            gmaAdChoicesView.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(gmaAdChoicesView)
            NSLayoutConstraint.activate([
                gmaAdChoicesView.topAnchor.constraint(equalTo: container.topAnchor),
                gmaAdChoicesView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                gmaAdChoicesView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                gmaAdChoicesView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])
        }
    }

    private func registerAssetViews() {
        headlineView = content.adHeadlineLabel
        bodyView = content.adBodyLabel
        mediaView = content.adMediaContainerView != nil ? gmaMediaView : nil
        imageView = content.adFallbackImageView
        iconView = content.adIconImageView
        callToActionView = content.usesWholeViewAsClickTarget ? self : content.adCallToActionView
        adChoicesView = content.adChoicesContainerView != nil ? gmaAdChoicesView : nil
    }
}
