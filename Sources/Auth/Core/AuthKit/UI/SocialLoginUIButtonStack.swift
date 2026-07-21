//
//  SocialLoginUIButtonStack.swift
//  AppFoundation / AuthKit
//
//  조립 시 등록한 provider 만 그리는 로그인 버튼 스택 (UIKit, UIStackView).
//  `AuthService.loginOptions` 를 그대로 받아 순서대로 노출한다.
//
//  사용 예:
//      let stack = SocialLoginUIButtonStack(options: auth.loginOptions)
//          .setCornerRadius(16)
//          .setOnTap { [weak self] provider in self?.signIn(provider) }
//      stack.setLoading(true)   // 요청 중 전 버튼 스피너 + 비활성
//

import UIKit

public final class SocialLoginUIButtonStack: UIStackView {

    private var buttons: [SocialLoginUIButton] = []
    private var onTap: ((SocialProvider) -> Void)?

    // MARK: - Init

    public init(options: [SocialLoginOption]) {
        super.init(frame: .zero)

        axis = .vertical
        spacing = 12

        for option in options {
            let button = SocialLoginUIButton(option: option)
                .setOnTap { [weak self] in self?.onTap?(option.provider) }
            buttons.append(button)
            addArrangedSubview(button)
        }
    }

    @available(*, unavailable, message: "init(options:) 을 사용하세요")
    public required init(coder: NSCoder) {
        fatalError("init(options:) 을 사용하세요")
    }

    // MARK: - set 모디파이어 (빌더, Self 반환 — 전 버튼 일괄 적용)

    /// 전 버튼 공통 모서리 반경. 기본 12.
    @discardableResult
    public func setCornerRadius(_ radius: CGFloat) -> Self {
        buttons.forEach { $0.setCornerRadius(radius) }
        return self
    }

    /// 전 버튼 공통 높이. 기본 52.
    @discardableResult
    public func setHeight(_ height: CGFloat) -> Self {
        buttons.forEach { $0.setHeight(height) }
        return self
    }

    /// 버튼 사이 간격. 기본 12.
    @discardableResult
    public func setSpacing(_ spacing: CGFloat) -> Self {
        self.spacing = spacing
        return self
    }

    /// 탭 핸들러 — 눌린 버튼의 provider 가 전달된다.
    @discardableResult
    public func setOnTap(_ handler: @escaping (SocialProvider) -> Void) -> Self {
        onTap = handler
        return self
    }

    /// 로딩 상태 — true 면 전 버튼 스피너 표시 + 터치 비활성.
    @discardableResult
    public func setLoading(_ loading: Bool) -> Self {
        buttons.forEach { $0.setLoading(loading) }
        return self
    }
}
