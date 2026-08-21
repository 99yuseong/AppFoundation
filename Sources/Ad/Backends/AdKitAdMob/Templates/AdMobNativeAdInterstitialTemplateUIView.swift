//
//  AdMobNativeAdInterstitialTemplateUIView.swift
//  AppFoundation / AdKitAdMob
//
//  전면형 네이티브 광고의 "카드" 기본 템플릿 (TumTumRead 레이아웃 이식).
//
//  이 뷰 자체가 곧 카드이며, 크기도 카드 콘텐츠에 딱 맞는다. 검은 배경 /
//  닫기 버튼 / 카운트다운 UI 는 `AdMobNativeAdInterstitialViewController` 가 이 뷰
//  바깥에 배치한다. GMA 트래킹 연결은 `AdMobNativeAdHostUIView` 가 수행하고, 카드
//  전체가 클릭 영역이 되어 배경 탭은 광고 클릭으로 이어지지 않는다.
//
//  스타일은 `set~` 빌더로 조정한다 (색·폰트·radius·미디어 비율). 레이아웃
//  자체를 바꾸려면 `NativeAdLayoutUIView` 를 직접 상속한 커스텀 뷰를 VC 에
//  주입한다 — 이 템플릿이 그 구현 예시이기도 하다.
//

import UIKit
import AdKit

public final class AdMobNativeAdInterstitialTemplateUIView: NativeAdLayoutUIView {

    // MARK: - UI Components

    private let adLabel: PaddedLabel = {
        let label = PaddedLabel()
        label.text = "AD"
        label.textColor = .white
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 12, weight: .bold)
        label.backgroundColor = UIColor(red: 60/255, green: 60/255, blue: 65/255, alpha: 1.0)
        label.textInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        label.layer.cornerRadius = 6
        label.layer.masksToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    /// AdChoices(광고 정보) 아이콘 자리 — 호스트가 SDK 뷰를 삽입한다.
    private let adChoicesSlotView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 미디어 프레임 (둥근 모서리) — 미디어 자리와 fallback 이미지를 담는다.
    private let mediaFrameView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.layer.cornerRadius = 12
        view.layer.masksToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 미디어(영상/이미지) 자리 — 호스트가 SDK 미디어 뷰를 삽입하며,
    /// contentMode(.scaleAspectFill)가 삽입된 뷰에 그대로 비춰진다.
    private let mediaSlotView: UIView = {
        let view = UIView()
        view.contentMode = .scaleAspectFill
        view.backgroundColor = .black
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let fallbackImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .black
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isHidden = true
        return imageView
    }()

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .white
        imageView.layer.cornerRadius = 8
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let headlineLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .bold)
        label.textColor = .white
        label.numberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let bodyLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = UIColor.white.withAlphaComponent(0.6)
        label.numberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let ctaButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.backgroundColor = UIColor(red: 56/255, green: 132/255, blue: 255/255, alpha: 1.0)
        button.layer.cornerRadius = 14
        button.translatesAutoresizingMaskIntoConstraints = false
        // SDK 가 등록된 뷰의 탭을 처리하므로 버튼 자체 인터랙션은 끈다
        button.isUserInteractionEnabled = false
        return button
    }()

    private lazy var infoStackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [iconImageView, textStackView])
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var textStackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [headlineLabel, bodyLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // MARK: - Constraints

    private var mediaHeightConstraint: NSLayoutConstraint?

    // MARK: - Layout

    public override func setupLayout() {
        configureCardStyle()
        configureHierarchy()
        configureLayout()
    }

    /// 이 뷰 자체에 카드 스타일(둥근 모서리 + 테두리)을 적용한다.
    private func configureCardStyle() {
        backgroundColor = UIColor(red: 30/255, green: 30/255, blue: 35/255, alpha: 1.0)
        layer.cornerRadius = 20
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
        layer.masksToBounds = true
    }

    private func configureHierarchy() {
        addSubview(adLabel)
        addSubview(adChoicesSlotView)
        addSubview(mediaFrameView)
        addSubview(infoStackView)
        addSubview(ctaButton)

        mediaFrameView.addSubview(mediaSlotView)
        mediaFrameView.addSubview(fallbackImageView)
    }

    private func configureLayout() {
        NSLayoutConstraint.activate([

            // AD Label (카드 내 좌측 상단)
            adLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            adLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),

            // AdChoices (카드 우측 하단)
            adChoicesSlotView.bottomAnchor.constraint(equalTo: bottomAnchor),
            adChoicesSlotView.trailingAnchor.constraint(equalTo: trailingAnchor),
            adChoicesSlotView.widthAnchor.constraint(equalToConstant: 20),
            adChoicesSlotView.heightAnchor.constraint(equalToConstant: 20),

            // Media Frame (둥근 모서리 미디어 영역)
            mediaFrameView.topAnchor.constraint(equalTo: adLabel.bottomAnchor, constant: 16),
            mediaFrameView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            mediaFrameView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            // Media Slot (프레임에 맞춤)
            mediaSlotView.topAnchor.constraint(equalTo: mediaFrameView.topAnchor),
            mediaSlotView.leadingAnchor.constraint(equalTo: mediaFrameView.leadingAnchor),
            mediaSlotView.trailingAnchor.constraint(equalTo: mediaFrameView.trailingAnchor),
            mediaSlotView.bottomAnchor.constraint(equalTo: mediaFrameView.bottomAnchor),

            // Fallback ImageView (미디어 자리와 동일 위치)
            fallbackImageView.topAnchor.constraint(equalTo: mediaFrameView.topAnchor),
            fallbackImageView.leadingAnchor.constraint(equalTo: mediaFrameView.leadingAnchor),
            fallbackImageView.trailingAnchor.constraint(equalTo: mediaFrameView.trailingAnchor),
            fallbackImageView.bottomAnchor.constraint(equalTo: mediaFrameView.bottomAnchor),

            // Icon ImageView
            iconImageView.widthAnchor.constraint(equalToConstant: 56),
            iconImageView.heightAnchor.constraint(equalToConstant: 56),

            // Info StackView (아이콘 + 텍스트)
            infoStackView.topAnchor.constraint(equalTo: mediaFrameView.bottomAnchor, constant: 20),
            infoStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            infoStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            // CTA Button
            ctaButton.topAnchor.constraint(equalTo: infoStackView.bottomAnchor, constant: 16),
            ctaButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            ctaButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            ctaButton.heightAnchor.constraint(equalToConstant: 52),
            ctaButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20)
        ])

        // 미디어 영역 기본 비율 1:1 (setMediaAspectRatio 로 변경)
        applyMediaAspectRatio(widthToHeight: 1.0)
    }

    private func applyMediaAspectRatio(widthToHeight ratio: CGFloat) {
        mediaHeightConstraint?.isActive = false
        mediaHeightConstraint = mediaFrameView.heightAnchor.constraint(
            equalTo: mediaFrameView.widthAnchor,
            multiplier: 1.0 / ratio
        )
        mediaHeightConstraint?.isActive = true
    }

    // MARK: - set~ 빌더 (스타일 주입)

    @discardableResult
    public func setCardBackgroundColor(_ color: UIColor) -> Self {
        backgroundColor = color
        return self
    }

    @discardableResult
    public func setCardCornerRadius(_ radius: CGFloat) -> Self {
        layer.cornerRadius = radius
        return self
    }

    @discardableResult
    public func setCardBorder(color: UIColor, width: CGFloat) -> Self {
        layer.borderColor = color.cgColor
        layer.borderWidth = width
        return self
    }

    @discardableResult
    public func setHeadlineFont(_ font: UIFont) -> Self {
        headlineLabel.font = font
        return self
    }

    @discardableResult
    public func setHeadlineTextColor(_ color: UIColor) -> Self {
        headlineLabel.textColor = color
        return self
    }

    @discardableResult
    public func setBodyFont(_ font: UIFont) -> Self {
        bodyLabel.font = font
        return self
    }

    @discardableResult
    public func setBodyTextColor(_ color: UIColor) -> Self {
        bodyLabel.textColor = color
        return self
    }

    @discardableResult
    public func setCTABackgroundColor(_ color: UIColor) -> Self {
        ctaButton.backgroundColor = color
        return self
    }

    @discardableResult
    public func setCTATitleColor(_ color: UIColor) -> Self {
        ctaButton.setTitleColor(color, for: .normal)
        return self
    }

    @discardableResult
    public func setCTACornerRadius(_ radius: CGFloat) -> Self {
        ctaButton.layer.cornerRadius = radius
        return self
    }

    /// 미디어 영역 비율 (가로/세로 — 예: 1.0 = 정사각형, 16.0/9.0 = 와이드).
    @discardableResult
    public func setMediaAspectRatio(_ widthToHeight: CGFloat) -> Self {
        applyMediaAspectRatio(widthToHeight: widthToHeight)
        return self
    }

    // MARK: - NativeAdLayoutUIView

    public override var adHeadlineLabel: UILabel? { headlineLabel }
    public override var adBodyLabel: UILabel? { bodyLabel }
    public override var adMediaContainerView: UIView? { mediaSlotView }
    public override var adFallbackImageView: UIImageView? { fallbackImageView }
    public override var adIconImageView: UIImageView? { iconImageView }
    public override var adChoicesContainerView: UIView? { adChoicesSlotView }

    /// 카드 전체를 광고 클릭 영역으로 사용
    public override var usesWholeViewAsClickTarget: Bool { true }

    public override func configureDefaultContent() {
        headlineLabel.text = String(localized: "Ad.Interstitial.Fallback.headline", bundle: .module)
        bodyLabel.text = String(localized: "Ad.Interstitial.Fallback.noFillBody", bundle: .module)

        iconImageView.isHidden = false
        iconImageView.tintColor = UIColor.white.withAlphaComponent(0.7)
        iconImageView.image = UIImage(systemName: "megaphone.fill")

        mediaSlotView.isHidden = true
        fallbackImageView.isHidden = false
        fallbackImageView.tintColor = UIColor.white.withAlphaComponent(0.35)
        fallbackImageView.image = UIImage(systemName: "photo")

        ctaButton.isHidden = true
    }

    public override func configure(with content: NativeAdContent) {

        // Headline
        let headline = content.headline?.trimmingCharacters(in: .whitespacesAndNewlines)
        headlineLabel.text = (headline?.isEmpty == false)
            ? headline
            : String(localized: "Ad.Interstitial.Fallback.headline", bundle: .module)

        // Body
        let body = content.body?.trimmingCharacters(in: .whitespacesAndNewlines)
        bodyLabel.text = (body?.isEmpty == false)
            ? body
            : String(localized: "Ad.Interstitial.Fallback.emptyBody", bundle: .module)

        // Icon
        if let icon = content.iconImage {
            iconImageView.image = icon
            iconImageView.tintColor = nil
            iconImageView.isHidden = false
        } else {
            iconImageView.isHidden = false
            iconImageView.tintColor = UIColor.white.withAlphaComponent(0.7)
            iconImageView.image = UIImage(systemName: "megaphone.fill")
        }

        if content.hasMediaContent {
            mediaSlotView.isHidden = false
            fallbackImageView.isHidden = true
            fallbackImageView.image = nil

        } else if let firstImage = content.fallbackImage {
            mediaSlotView.isHidden = true
            fallbackImageView.isHidden = false
            fallbackImageView.tintColor = nil
            fallbackImageView.image = firstImage

        } else {
            mediaSlotView.isHidden = true
            fallbackImageView.isHidden = false
            fallbackImageView.tintColor = UIColor.white.withAlphaComponent(0.35)
            fallbackImageView.image = UIImage(systemName: "photo")
        }

        // CTA Button
        if let callToAction = content.callToActionText, !callToAction.isEmpty {
            ctaButton.setTitle(callToAction, for: .normal)
        } else {
            ctaButton.setTitle(String(localized: "Ad.Interstitial.Fallback.cta", bundle: .module), for: .normal)
        }
        ctaButton.isHidden = false
    }
}
