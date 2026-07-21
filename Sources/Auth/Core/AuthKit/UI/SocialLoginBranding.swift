//
//  SocialLoginBranding.swift
//  AppFoundation / AuthKit
//
//  로그인 버튼의 브랜드 디자인 값 타입. 버튼은 provider 를 switch 하지 않는다 —
//  각 `AuthProvider` 가 자기 branding 을 소유하고(기본값 내장 + 생성자 오버라이드),
//  조립 지점에서 주입된 값이 `AuthService.loginOptions` 를 거쳐 UI 까지 흐른다.
//  새 provider 는 branding 값을 하나 만들면 버튼 코드 수정 없이 노출된다.
//

import UIKit

/// 소셜 로그인 버튼 하나의 브랜드 스펙(문구·색·로고).
public struct SocialLoginBranding: Sendable {

    /// 버튼 문구 — 로컬라이즈가 끝난 문자열을 담는다.
    /// (기본 3종은 AuthKit 의 ko/en/ja 리소스를 쓴다)
    public var title: String
    public var foreground: UIColor
    public var background: UIColor
    /// nil 이면 테두리 없음.
    public var border: UIColor?
    public var logo: Logo

    public enum Logo: Sendable {
        /// SF Symbol 로고. `verticalOffset` 은 시각 보정용(음수 = 위로).
        case sfSymbol(name: String, verticalOffset: CGFloat)

        /// CGPath 로고 — rect 를 받아 (path, color) 목록을 돌려준다.
        /// color 가 nil 이면 branding 의 `foreground` 로 채운다.
        case paths(@Sendable (CGRect) -> [(path: CGPath, color: UIColor?)])

        /// 이미지 에셋 로고 — 브랜드 가이드라인이 원본 에셋 사용을 요구할 때
        /// (예: Google G). 원본 색을 유지하려 `.alwaysOriginal` 로 렌더한다.
        case image(UIImage)

        public static func sfSymbol(_ name: String) -> Logo {
            .sfSymbol(name: name, verticalOffset: 0)
        }

        /// AuthKit 번들의 이미지 에셋을 이름으로 참조한다.
        public static func asset(_ name: String) -> Logo {
            .image(UIImage(named: name, in: .module, compatibleWith: nil) ?? UIImage())
        }
    }

    public init(
        title: String,
        foreground: UIColor,
        background: UIColor,
        border: UIColor? = nil,
        logo: Logo
    ) {
        self.title = title
        self.foreground = foreground
        self.background = background
        self.border = border
        self.logo = logo
    }
}

// MARK: - 기본 3종 (Mock·단독 사용·로컬라이제이션을 한 곳에)

extension SocialLoginBranding {

    /// Apple HIG 버튼 (.black / .white / .whiteOutline).
    public static func apple(_ style: AppleLoginStyle = .black) -> Self {
        SocialLoginBranding(
            title: String(localized: "social.login.apple", bundle: .module),
            foreground: style == .black ? .white : .black,
            background: style == .black ? .black : .white,
            border: style == .whiteOutline ? SocialLoginLogo.BrandColor.appleOutlineBorder : nil,
            // 로고 하단이 살짝 무거워 -1 보정
            logo: .sfSymbol(name: "apple.logo", verticalOffset: -1)
        )
    }

    public static let google = SocialLoginBranding(
        title: String(localized: "social.login.google", bundle: .module),
        foreground: SocialLoginLogo.BrandColor.googleForeground,
        background: .white,
        border: SocialLoginLogo.BrandColor.googleBorder,
        // 공식 G 로고 에셋 (Doran DesignGuide 에서 이식) — 구글 브랜드
        // 가이드라인상 로고는 재현하지 않고 원본 에셋을 쓴다.
        logo: .asset("GoogleLogo")
    )

    public static let kakao = SocialLoginBranding(
        title: String(localized: "social.login.kakao", bundle: .module),
        foreground: SocialLoginLogo.BrandColor.kakaoForeground,
        background: SocialLoginLogo.BrandColor.kakaoBackground,
        // TumTumRead 와 동일하게 SF Symbol 말풍선을 쓴다.
        logo: .sfSymbol("message.fill")
    )
}

// MARK: - 로그인 옵션 (UI 노출 단위)

/// "이 provider 를 이 디자인으로 노출한다" 하나. `AuthService.loginOptions` 가
/// 조립 시 주입된 provider 들로부터 이 목록을 만든다 — 주입 순서 = 노출 순서.
public struct SocialLoginOption: Sendable {

    public let provider: SocialProvider
    public let branding: SocialLoginBranding

    public init(provider: SocialProvider, branding: SocialLoginBranding) {
        self.provider = provider
        self.branding = branding
    }
}
