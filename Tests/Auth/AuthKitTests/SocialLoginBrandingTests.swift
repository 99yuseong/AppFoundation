//
//  SocialLoginBrandingTests.swift
//  AppFoundation / AuthKitTests
//
//  `.asset(_:)` 은 이름이 틀리거나 리소스가 번들에서 빠져도 빈 UIImage 로
//  조용히 폴백한다 — 컴파일도 통과한다. 번들 동봉 여부는 여기서만 잡힌다.
//

import UIKit
import Testing
@testable import AuthKit

@Suite("SocialLoginBranding")
struct SocialLoginBrandingTests {

    @Test("Google 로고 에셋이 번들에 실려 있다")
    func googleLogoAssetIsBundled() {
        guard case let .image(image) = SocialLoginBranding.google.logo else {
            Issue.record("google 로고가 .image 가 아니다")
            return
        }

        // 폴백(빈 UIImage)이면 크기가 0 이다.
        #expect(image.size.width > 0)
        #expect(image.size.height > 0)
    }
}
