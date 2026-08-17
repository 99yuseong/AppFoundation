//
//  NativeAdInterstitialViewController.swift
//  AppFoundation / AdKitAdMob
//
//  네이티브 광고를 전면 광고 형태로 표시하는 뷰컨트롤러.
//
//  검은 배경 위에 광고 카드(주입된 `NativeAdLayoutUIView`, 기본은
//  `InterstitialNativeAdTemplateUIView`)를 중앙 배치하고, 카드 아래에 카운트다운
//  닫기 버튼(+선택적 전환 유도 버튼)을 둔다. 표시 시점에
//  `AdMobCachedNativeAdLoader` 의 캐시를 1회 소비한다 — 미리 `loadAd()` 를
//  호출해 두어야 한다.
//
//  설정은 present 전에 `set~` 빌더로 조정한다.
//
//  ```swift
//  let vc = NativeAdInterstitialViewController(adLoader: loader)
//      .setCloseButtonUnlockInterval(5)
//      .setPromotionButtonTitle("구독하고 광고 없이 이용하기")
//  vc.onCloseButtonTapped = { ... }
//  presenter.present(vc, animated: true)
//  ```
//

import UIKit
import AdKit

public final class NativeAdInterstitialViewController: UIViewController {

    // MARK: - Callbacks

    public var onCloseButtonTapped: (() -> Void)?
    /// 표시 시점에 로드된 광고가 없을 때 호출된다 (기본 콘텐츠 표시 모드가 아니면).
    public var onAdNotReady: (() -> Void)?
    public var onPromotionButtonTapped: (() -> Void)?
    public var onPromotionButtonImpression: (() -> Void)?

    // MARK: - Properties

    private let adLoader: AdMobCachedNativeAdLoader
    private var closeButtonUnlockInterval: TimeInterval = 5
    private var promotionButtonTitle: String?
    /// true 면 광고 미준비 시 `onAdNotReady` 대신 기본 콘텐츠를 표시한다 (UI 테스트용)
    private var showsDefaultContentWhenAdMissing = false
    private var adContentView: NativeAdLayoutUIView = InterstitialNativeAdTemplateUIView()
    /// SwiftUI 래퍼는 false 로 바꿔 dismiss 를 앱 상태(binding)가 소유하게 한다.
    var dismissesOnCloseTap = true

    private var hasStartedCountdown = false

    // MARK: - UI Components

    /// 광고 카드. 주입받은 레이아웃을 `NativeAdHostUIView` 로 감싸 트래킹을 연결한다.
    /// 크기는 카드 콘텐츠 크기에 맞춰지며, 화면 중앙에 배치된다. (viewDidLoad 에서 생성)
    private var interstitialView: NativeAdHostUIView!

    /// 닫기 버튼(카운트다운 포함). 카드 바깥, 카드와 화면 바닥 사이 중앙에 배치된다.
    private lazy var closeButton: AdCloseCountdownButton = {
        let button = AdCloseCountdownButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.onTapped = { [weak self] in
            self?.didCloseButtonTapped()
        }
        return button
    }()

    /// 로그인/구독 등 전환 유도 버튼. 카드와 닫기 버튼 사이에 배치되며, 타이틀이 없으면 표시하지 않는다.
    private lazy var promotionButton: UIButton = {
        let button = UIButton(type: .system)

        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: "chevron.right")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 13, weight: .bold))
        config.imagePlacement = .trailing
        config.imagePadding = 6
        config.baseBackgroundColor = .white
        config.baseForegroundColor = .black
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 24, bottom: 14, trailing: 20)
        config.attributedTitle = promotionButtonTitle.map {
            AttributedString($0, attributes: .init([.font: UIFont.systemFont(ofSize: 16, weight: .bold)]))
        }
        button.configuration = config

        button.addAction(UIAction { [weak self] _ in
            self?.didPromotionButtonTapped()
        }, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// CTA 와 닫기 버튼을 한 묶음으로 만들어 광고 카드 하단~화면 하단의 정중앙에 배치한다.
    private let actionStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // MARK: - Initialization

    public init(adLoader: AdMobCachedNativeAdLoader) {
        self.adLoader = adLoader
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - set~ 빌더 (present 전에 호출)

    /// 닫기 버튼이 활성화될 때까지의 카운트다운(초). 0 이하 = 즉시 활성.
    @discardableResult
    public func setCloseButtonUnlockInterval(_ interval: TimeInterval) -> Self {
        closeButtonUnlockInterval = interval
        return self
    }

    /// 전환 유도(로그인/구독) 버튼 타이틀. nil = 버튼 없음.
    @discardableResult
    public func setPromotionButtonTitle(_ title: String?) -> Self {
        promotionButtonTitle = title
        return self
    }

    /// 광고 카드 디자인. 기본은 `InterstitialNativeAdTemplateUIView`.
    @discardableResult
    public func setAdContentView(_ contentView: NativeAdLayoutUIView) -> Self {
        adContentView = contentView
        return self
    }

    /// true 면 광고 미준비 시 기본 콘텐츠를 표시한다 (기본: `onAdNotReady` 호출).
    @discardableResult
    public func setShowsDefaultContentWhenAdMissing(_ shows: Bool) -> Self {
        showsDefaultContentWhenAdMissing = shows
        return self
    }

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        interstitialView = NativeAdHostUIView(contentView: adContentView)
        configureUI()

        guard let nativeAd = adLoader.consumeAd() else {
            if showsDefaultContentWhenAdMissing {
                interstitialView.configureDefaultContent()
            } else {
                onAdNotReady?()
            }
            return
        }

        interstitialView.configure(with: nativeAd)
        if promotionButtonTitle != nil {
            onPromotionButtonImpression?()
        }
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // 카운트다운은 화면이 처음 나타날 때 한 번만 시작
        guard !hasStartedCountdown else { return }
        hasStartedCountdown = true
        closeButton.startCountdown(duration: closeButtonUnlockInterval)
    }

    // MARK: - Configuration

    private func configureUI() {
        // 검은 배경 (이 영역 탭은 광고 클릭과 무관)
        view.backgroundColor = .black

        view.addSubview(interstitialView)
        view.addSubview(actionStack)
        if promotionButtonTitle != nil {
            actionStack.addArrangedSubview(promotionButton)
        }
        actionStack.addArrangedSubview(closeButton)

        // 카드 하단 ~ 화면 실제 바닥 사이 공간. 닫기 버튼을 이 영역 중앙에 배치한다.
        let bottomSpacingGuide = UILayoutGuide()
        view.addLayoutGuide(bottomSpacingGuide)

        NSLayoutConstraint.activate([
            // 광고 카드: 화면 중앙(좌우 마진 20, 위로 살짝). 높이는 콘텐츠가 결정.
            interstitialView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            interstitialView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            interstitialView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),

            // 카드 하단 ~ 화면 바닥 사이 공간 가이드
            bottomSpacingGuide.topAnchor.constraint(equalTo: interstitialView.bottomAnchor),
            bottomSpacingGuide.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomSpacingGuide.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomSpacingGuide.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            // CTA+닫기 버튼 묶음 전체를 카드 하단~화면 하단 영역의 중앙에 둔다.
            actionStack.centerXAnchor.constraint(equalTo: bottomSpacingGuide.centerXAnchor),
            actionStack.centerYAnchor.constraint(equalTo: bottomSpacingGuide.centerYAnchor),
            actionStack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            actionStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            closeButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    // MARK: - Actions

    private func didCloseButtonTapped() {
        if dismissesOnCloseTap {
            dismiss(animated: true) { [weak self] in
                self?.onCloseButtonTapped?()
            }
        } else {
            onCloseButtonTapped?()
        }
    }

    private func didPromotionButtonTapped() {
        guard promotionButton.isEnabled else { return }
        promotionButton.isEnabled = false
        promotionButton.alpha = 0.45
        onPromotionButtonTapped?()
    }

    /// 로그인/구독 시트가 닫혀 광고 화면으로 돌아왔을 때 CTA 를 다시 활성화한다.
    public func enablePromotionButton() {
        guard promotionButtonTitle != nil, !promotionButton.isEnabled else { return }
        promotionButton.isEnabled = true
        UIView.animate(withDuration: 0.2) {
            self.promotionButton.alpha = 1
        }
    }
}
