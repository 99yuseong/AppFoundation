//
//  SocialLoginUIButton.swift
//  AppFoundation / AuthKit
//
//  소셜 로그인 버튼 (UIKit). SwiftUI 의 `SocialLoginButton` 과 동일한 브랜드
//  렌더링·빌더 체이닝을 UIControl 로 제공한다.
//
//  사용 예:
//      let button = SocialLoginUIButton()
//          .setProvider(.kakao)
//          .setCornerRadius(16)
//          .setOnTap { [weak self] in self?.signInKakao() }
//      button.setLoading(true)   // 요청 중 스피너 + 비활성
//

import UIKit

public final class SocialLoginUIButton: UIControl {

    // MARK: - 설정값

    private var provider: SocialProvider = .apple
    private var appleStyle: AppleLoginStyle = .black
    private var buttonHeight: CGFloat = 52
    private var onTap: (() -> Void)?

    // MARK: - Subviews

    private let contentStack = UIStackView()
    private let logoContainer = UIView()
    private let appleLogoView = UIImageView(
        image: UIImage(systemName: "apple.logo", withConfiguration:
            UIImage.SymbolConfiguration(pointSize: 17, weight: .medium))
    )
    private let drawnLogoView = LogoDrawView()
    private let titleLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)

    // MARK: - Init

    public init() {
        super.init(frame: .zero)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    // MARK: - set 모디파이어 (빌더, Self 반환)

    /// 브랜드 렌더링(색·로고·문구) 전환. 기본 `.apple`.
    @discardableResult
    public func setProvider(_ provider: SocialProvider) -> Self {
        self.provider = provider
        applyBranding()
        return self
    }

    /// 모서리 반경. 기본 12.
    @discardableResult
    public func setCornerRadius(_ radius: CGFloat) -> Self {
        layer.cornerRadius = radius
        return self
    }

    /// 버튼 높이(intrinsicContentSize). 기본 52.
    @discardableResult
    public func setHeight(_ height: CGFloat) -> Self {
        buttonHeight = height
        invalidateIntrinsicContentSize()
        return self
    }

    /// Apple 버튼 HIG 스타일. provider 가 `.apple` 이 아닐 때는 무시된다.
    @discardableResult
    public func setAppleStyle(_ style: AppleLoginStyle) -> Self {
        appleStyle = style
        applyBranding()
        return self
    }

    /// 탭 핸들러.
    @discardableResult
    public func setOnTap(_ handler: @escaping () -> Void) -> Self {
        onTap = handler
        return self
    }

    /// 로딩 상태 — true 면 스피너 표시 + 터치 비활성.
    @discardableResult
    public func setLoading(_ loading: Bool) -> Self {
        isEnabled = !loading
        contentStack.alpha = loading ? 0 : 1
        if loading {
            spinner.startAnimating()
        } else {
            spinner.stopAnimating()
        }
        return self
    }

    // MARK: - UIControl

    public override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: buttonHeight)
    }

    public override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.75 : 1 }
    }

    // MARK: - Setup

    private func setup() {
        layer.cornerRadius = 12
        clipsToBounds = true

        contentStack.axis = .horizontal
        contentStack.spacing = 8
        contentStack.alignment = .center
        contentStack.isUserInteractionEnabled = false

        logoContainer.addSubview(appleLogoView)
        logoContainer.addSubview(drawnLogoView)
        drawnLogoView.backgroundColor = .clear

        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)

        contentStack.addArrangedSubview(logoContainer)
        contentStack.addArrangedSubview(titleLabel)
        addSubview(contentStack)

        spinner.hidesWhenStopped = true
        addSubview(spinner)

        [contentStack, logoContainer, appleLogoView, drawnLogoView, spinner].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            contentStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            contentStack.centerYAnchor.constraint(equalTo: centerYAnchor),

            logoContainer.widthAnchor.constraint(equalToConstant: 18),
            logoContainer.heightAnchor.constraint(equalToConstant: 18),
            appleLogoView.centerXAnchor.constraint(equalTo: logoContainer.centerXAnchor),
            appleLogoView.centerYAnchor.constraint(equalTo: logoContainer.centerYAnchor, constant: -1),
            drawnLogoView.topAnchor.constraint(equalTo: logoContainer.topAnchor),
            drawnLogoView.bottomAnchor.constraint(equalTo: logoContainer.bottomAnchor),
            drawnLogoView.leadingAnchor.constraint(equalTo: logoContainer.leadingAnchor),
            drawnLogoView.trailingAnchor.constraint(equalTo: logoContainer.trailingAnchor),

            spinner.centerXAnchor.constraint(equalTo: centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        addTarget(self, action: #selector(handleTap), for: .touchUpInside)

        applyBranding()
    }

    @objc private func handleTap() {
        onTap?()
    }

    // MARK: - 브랜드 렌더링 (SwiftUI 버전과 동일 스펙)

    private func applyBranding() {
        let foreground: UIColor
        let background: UIColor
        var borderColor: UIColor?

        switch provider {
        case .apple:
            foreground = appleStyle == .black ? .white : .black
            background = appleStyle == .black ? .black : .white
            borderColor = appleStyle == .whiteOutline
                ? SocialLoginLogo.BrandColor.appleOutlineBorder
                : nil
            titleLabel.text = String(localized: "social.login.apple", bundle: .module)

        case .google:
            foreground = SocialLoginLogo.BrandColor.googleForeground
            background = .white
            borderColor = SocialLoginLogo.BrandColor.googleBorder
            titleLabel.text = String(localized: "social.login.google", bundle: .module)

        case .kakao:
            foreground = SocialLoginLogo.BrandColor.kakaoForeground
            background = SocialLoginLogo.BrandColor.kakaoBackground
            titleLabel.text = String(localized: "social.login.kakao", bundle: .module)
        }

        backgroundColor = background
        titleLabel.textColor = foreground
        spinner.color = foreground
        layer.borderColor = borderColor?.cgColor
        layer.borderWidth = borderColor == nil ? 0 : 1

        appleLogoView.isHidden = provider != .apple
        appleLogoView.tintColor = foreground
        drawnLogoView.isHidden = provider == .apple
        drawnLogoView.provider = provider
        drawnLogoView.fillColor = foreground
        drawnLogoView.setNeedsDisplay()
    }
}

// MARK: - 로고 드로잉 (CGPath 공유 정의를 UIKit 으로)

private final class LogoDrawView: UIView {

    var provider: SocialProvider = .apple
    var fillColor: UIColor = .black

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        switch provider {
        case .apple:
            break // UIImageView(SF Symbol) 가 담당

        case .kakao:
            context.addPath(SocialLoginLogo.kakaoBubblePath(in: rect))
            context.setFillColor(fillColor.cgColor)
            context.fillPath()

        case .google:
            for segment in SocialLoginLogo.googleSegments(in: rect) {
                context.addPath(segment.path)
                context.setFillColor(segment.color.cgColor)
                context.fillPath()
            }
        }
    }
}
