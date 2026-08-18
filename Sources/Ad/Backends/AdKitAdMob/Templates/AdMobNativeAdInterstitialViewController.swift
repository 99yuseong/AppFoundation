//
//  AdMobNativeAdInterstitialViewController.swift
//  AppFoundation / AdKitAdMob
//
//  네이티브 광고를 전면 광고 형태로 표시하는 뷰컨트롤러.
//
//  검은 배경 위에 광고 카드(주입된 `NativeAdLayoutUIView`, 기본은
//  `AdMobNativeAdInterstitialTemplateUIView`)를 중앙 배치하고, 카드 아래에 카운트다운
//  닫기 버튼을 둔다. 닫기 버튼 위 하단 영역은 커스텀 뷰 슬롯이다 — 앱이
//  구독 유도 CTA 등 자기 뷰를 주입하고, 기본은 닫기 버튼만 표시한다.
//  표시 시점에 `AdMobNativeAdCachedLoader` 의 캐시를 1회 소비한다 — 미리
//  `loadAd()` 를 호출해 두어야 한다.
//
//  설정은 present 전에 `set~` 빌더로 조정한다.
//
//  ```swift
//  let vc = AdMobNativeAdInterstitialViewController(adLoader: loader)
//      .setCloseButtonUnlockInterval(5)
//      .setBottomAccessoryView(mySubscribeButton)   // 선택 — 없으면 닫기만
//      .setOnClose { ... }
//  presenter.present(vc, animated: true)
//  ```
//

import UIKit
import GoogleMobileAds
import AdKit

public final class AdMobNativeAdInterstitialViewController: UIViewController {

    // MARK: - Callbacks

    private var onClose: (() -> Void)?
    private var onAdNotReady: (() -> Void)?

    // MARK: - Properties

    private let adLoader: any NativeAdCachedLoading<NativeAd>
    private var closeButtonUnlockInterval: TimeInterval = 5
    /// 닫기 버튼 위에 배치할 커스텀 뷰 (구독 유도 CTA 등). nil = 닫기 버튼만.
    /// 뷰의 동작(탭 액션·비활성화 등)은 전적으로 앱이 소유한다.
    private var bottomAccessoryView: UIView?
    /// true 면 광고 미준비 시 `onAdNotReady` 대신 기본 콘텐츠를 표시한다 (UI 테스트용)
    private var showsDefaultContentWhenAdMissing = false
    private var adContentView: NativeAdLayoutUIView = AdMobNativeAdInterstitialTemplateUIView()
    /// SwiftUI 래퍼는 false 로 바꿔 dismiss 를 앱 상태(binding)가 소유하게 한다.
    var dismissesOnCloseTap = true

    private var hasStartedCountdown = false

    // MARK: - UI Components

    /// 광고 카드. 주입받은 레이아웃을 `AdMobNativeAdHostUIView` 로 감싸 트래킹을 연결한다.
    /// 크기는 카드 콘텐츠 크기에 맞춰지며, 화면 중앙에 배치된다. (viewDidLoad 에서 생성)
    private var interstitialView: AdMobNativeAdHostUIView!

    /// 닫기 버튼(카운트다운 포함). 카드 바깥, 카드와 화면 바닥 사이 중앙에 배치된다.
    private lazy var closeButton: AdCloseCountdownButton = {
        let button = AdCloseCountdownButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.onTapped = { [weak self] in
            self?.didCloseButtonTapped()
        }
        return button
    }()

    /// 하단 커스텀 뷰와 닫기 버튼을 한 묶음으로 만들어 광고 카드 하단~화면 하단의 정중앙에 배치한다.
    private let actionStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // MARK: - Initialization

    /// - Parameter adLoader: cache-one 네이티브 로더 (계약 주입 — 앱 자체 로더도
    ///   `NativeAdCachedLoading` 채택으로 주입 가능. 기본 구현은 `AdMobNativeAdCachedLoader`).
    public init(adLoader: any NativeAdCachedLoading<NativeAd>) {
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

    /// 닫기 버튼 위에 배치할 커스텀 뷰 (구독 유도 CTA 등). nil = 닫기 버튼만.
    /// 탭 액션 등 동작은 뷰를 만든 앱이 소유한다.
    @discardableResult
    public func setBottomAccessoryView(_ view: UIView?) -> Self {
        bottomAccessoryView = view
        return self
    }

    /// 광고 카드 디자인. 기본은 `AdMobNativeAdInterstitialTemplateUIView`.
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

    /// 닫기 버튼 탭 콜백.
    @discardableResult
    public func setOnClose(_ action: (() -> Void)?) -> Self {
        onClose = action
        return self
    }

    /// 표시 시점에 로드된 광고가 없을 때 콜백 (기본 콘텐츠 표시 모드가 아니면).
    @discardableResult
    public func setOnAdNotReady(_ action: (() -> Void)?) -> Self {
        onAdNotReady = action
        return self
    }

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        interstitialView = AdMobNativeAdHostUIView(contentView: adContentView)
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

        interstitialView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(interstitialView)
        view.addSubview(actionStack)
        if let bottomAccessoryView {
            actionStack.addArrangedSubview(bottomAccessoryView)
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

            // 하단 뷰+닫기 버튼 묶음 전체를 카드 하단~화면 하단 영역의 중앙에 둔다.
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
                self?.onClose?()
            }
        } else {
            onClose?()
        }
    }

}
