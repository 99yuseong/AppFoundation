//
//  SocialLoginUIButton.swift
//  AppFoundation / AuthKit
//
//  소셜 로그인 버튼 (UIKit). SwiftUI 의 `SocialLoginButton` 과 동일하게 주입된
//  `SocialLoginOption` 의 branding 만 그린다 — provider switch 없음.
//
//  보통은 `SocialLoginUIButtonStack` 을 쓰고, 단독 사용은:
//      let button = SocialLoginUIButton(option: .init(provider: .kakao, branding: .kakao))
//          .setCornerRadius(16)
//          .setOnTap { [weak self] in self?.signInKakao() }
//      button.setLoading(true)   // 요청 중 스피너 + 비활성
//

import UIKit

public final class SocialLoginUIButton: UIControl {

    // MARK: - 설정값

    public let option: SocialLoginOption
    private var buttonHeight: CGFloat = 52
    private var onTap: (() -> Void)?

    // MARK: - Subviews

    private let contentStack = UIStackView()
    private let logoContainer = UIView()
    private let symbolLogoView = UIImageView()
    private let drawnLogoView = LogoDrawView()
    private let titleLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)

    // MARK: - Init

    public init(option: SocialLoginOption) {
        self.option = option
        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable, message: "init(option:) 을 사용하세요")
    public required init?(coder: NSCoder) {
        fatalError("init(option:) 을 사용하세요")
    }

    // MARK: - set 모디파이어 (빌더, Self 반환)

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

        logoContainer.addSubview(symbolLogoView)
        logoContainer.addSubview(drawnLogoView)
        drawnLogoView.backgroundColor = .clear
        // SF Symbol 은 고유 크기로, 이미지 에셋(원본 200px 급)은 컨테이너에 맞춰
        // 축소돼야 한다 — 두 경우 모두 aspect fit 으로 처리한다.
        symbolLogoView.contentMode = .scaleAspectFit

        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)

        contentStack.addArrangedSubview(logoContainer)
        contentStack.addArrangedSubview(titleLabel)
        addSubview(contentStack)

        spinner.hidesWhenStopped = true
        addSubview(spinner)

        [contentStack, logoContainer, symbolLogoView, drawnLogoView, spinner].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        // symbolLogoView 의 y 제약은 branding 의 verticalOffset 을 따른다 (applyBranding).
        symbolCenterYConstraint = symbolLogoView.centerYAnchor
            .constraint(equalTo: logoContainer.centerYAnchor)

        NSLayoutConstraint.activate([
            contentStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            contentStack.centerYAnchor.constraint(equalTo: centerYAnchor),

            logoContainer.widthAnchor.constraint(equalToConstant: 18),
            logoContainer.heightAnchor.constraint(equalToConstant: 18),
            symbolLogoView.centerXAnchor.constraint(equalTo: logoContainer.centerXAnchor),
            symbolCenterYConstraint,
            // 컨테이너를 넘지 않게 상한만 건다 (SF Symbol 은 고유 크기 유지).
            symbolLogoView.widthAnchor.constraint(lessThanOrEqualTo: logoContainer.widthAnchor),
            symbolLogoView.heightAnchor.constraint(lessThanOrEqualTo: logoContainer.heightAnchor),
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

    private var symbolCenterYConstraint: NSLayoutConstraint!

    @objc private func handleTap() {
        onTap?()
    }

    // MARK: - 브랜드 렌더링 (branding 값 → UIKit, SwiftUI 버전과 동일 스펙)

    private func applyBranding() {
        let branding = option.branding

        backgroundColor = branding.background
        titleLabel.text = branding.title
        titleLabel.textColor = branding.foreground
        spinner.color = branding.foreground
        layer.borderColor = branding.border?.cgColor
        layer.borderWidth = branding.border == nil ? 0 : 1

        switch branding.logo {
        case let .sfSymbol(name, verticalOffset):
            symbolLogoView.image = UIImage(
                systemName: name,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
            )
            symbolLogoView.tintColor = branding.foreground
            symbolCenterYConstraint.constant = verticalOffset
            // .image 케이스에서 낮췄을 수 있으니 기본값으로 되돌린다.
            symbolLogoView.setContentCompressionResistancePriority(.required, for: .horizontal)
            symbolLogoView.setContentCompressionResistancePriority(.required, for: .vertical)
            symbolLogoView.isHidden = false
            drawnLogoView.isHidden = true

        case let .paths(segments):
            drawnLogoView.segments = segments
            drawnLogoView.fillColor = branding.foreground
            drawnLogoView.setNeedsDisplay()
            symbolLogoView.isHidden = true
            drawnLogoView.isHidden = false

        case let .image(image):
            // 브랜드 에셋은 원본 색 그대로 (tint 를 타지 않게).
            symbolLogoView.image = image.withRenderingMode(.alwaysOriginal)
            symbolCenterYConstraint.constant = 0
            // 원본 에셋은 컨테이너보다 훨씬 크다 — intrinsic size 를 양보시켜야
            // width/height 상한 제약이 실제로 먹는다.
            symbolLogoView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            symbolLogoView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
            symbolLogoView.isHidden = false
            drawnLogoView.isHidden = true
        }
    }
}

// MARK: - 로고 드로잉 (branding.logo.paths → UIKit)

private final class LogoDrawView: UIView {

    var segments: (@Sendable (CGRect) -> [(path: CGPath, color: UIColor?)])?
    var fillColor: UIColor = .black

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(), let segments else { return }

        for segment in segments(rect) {
            context.addPath(segment.path)
            context.setFillColor((segment.color ?? fillColor).cgColor)
            context.fillPath()
        }
    }
}
