//
//  SocialLoginLogo.swift
//  AppFoundation / AuthKit
//
//  로그인 버튼 브랜드 자산 — 색상 상수와 Apple 버튼 스타일.
//
//  로고 자체는 branding 이 소유한다: Apple/Kakao 는 SF Symbol,
//  Google 은 공식 에셋(Resources/Media.xcassets/GoogleLogo).
//  `SocialLoginBranding.Logo.paths` 케이스는 커스텀 provider 가 CGPath 로고를
//  쓸 때를 위해 남아 있다 — 기본 3종은 더 이상 쓰지 않는다.
//

import UIKit

/// Apple 버튼 HIG 3종 스타일. (SwiftUI·UIKit 공용)
public enum AppleLoginStyle: Sendable {
    case black
    case white
    case whiteOutline
}

enum SocialLoginLogo {

    // MARK: - 브랜드 컬러

    enum BrandColor {
        static let kakaoBackground = UIColor(red: 0xFE / 255, green: 0xE5 / 255, blue: 0x00 / 255, alpha: 1)
        static let kakaoForeground = UIColor.black.withAlphaComponent(0.85)

        static let googleForeground = UIColor(red: 0x1F / 255, green: 0x1F / 255, blue: 0x1F / 255, alpha: 1)
        static let googleBorder = UIColor(red: 0x74 / 255, green: 0x77 / 255, blue: 0x75 / 255, alpha: 1)

        static let appleOutlineBorder = UIColor.black.withAlphaComponent(0.3)
    }
}
