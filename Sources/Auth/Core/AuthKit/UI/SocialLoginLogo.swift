//
//  SocialLoginLogo.swift
//  AppFoundation / AuthKit
//
//  로그인 버튼 브랜드 자산 — 로고를 CGPath 로 정의해 SwiftUI(Canvas/Path)와
//  UIKit(draw/CAShapeLayer) 양쪽에서 재사용한다.
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
        static let googleBlue = UIColor(red: 0x42 / 255, green: 0x85 / 255, blue: 0xF4 / 255, alpha: 1)
        static let googleGreen = UIColor(red: 0x34 / 255, green: 0xA8 / 255, blue: 0x53 / 255, alpha: 1)
        static let googleYellow = UIColor(red: 0xFB / 255, green: 0xBC / 255, blue: 0x05 / 255, alpha: 1)
        static let googleRed = UIColor(red: 0xEA / 255, green: 0x43 / 255, blue: 0x35 / 255, alpha: 1)

        static let appleOutlineBorder = UIColor.black.withAlphaComponent(0.3)
    }

    // MARK: - Kakao 말풍선 (fill)

    static func kakaoBubblePath(in rect: CGRect) -> CGPath {
        let w = rect.width
        let h = rect.height
        let path = CGMutablePath()

        // 본체: 위쪽 타원
        path.addEllipse(in: CGRect(x: rect.minX, y: rect.minY, width: w, height: h * 0.8))

        // 꼬리: 좌하단 삼각형
        path.move(to: CGPoint(x: rect.minX + w * 0.36, y: rect.minY + h * 0.70))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.20, y: rect.minY + h * 0.98))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.52, y: rect.minY + h * 0.76))
        path.closeSubpath()

        return path
    }

    // MARK: - Google "G" (4색 fill 세그먼트)

    /// 공식 로고의 근사 — 4색 링 세그먼트 + 우측 가로 바. 전부 fill 가능한 path 로
    /// 변환해 반환하므로 stroke 파라미터 공유 문제가 없다.
    static func googleSegments(in rect: CGRect) -> [(path: CGPath, color: UIColor)] {
        let size = min(rect.width, rect.height)
        let lineWidth = size * 0.21
        let radius = size / 2 - lineWidth / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)

        // y-down 좌표계 기준 각도: 0°=우측, 90°=하단, 270°=상단
        func arc(_ from: CGFloat, _ to: CGFloat) -> CGPath {
            let path = CGMutablePath()
            path.addArc(
                center: center,
                radius: radius,
                startAngle: from * .pi / 180,
                endAngle: to * .pi / 180,
                clockwise: false
            )
            return path.copy(
                strokingWithWidth: lineWidth,
                lineCap: .butt,
                lineJoin: .miter,
                miterLimit: 10
            )
        }

        // 파랑: 우측 호 + 중앙→우측 가로 바
        let blue = CGMutablePath()
        blue.addPath(arc(-35, 45))
        blue.addRect(CGRect(
            x: center.x,
            y: center.y - lineWidth / 2,
            width: radius + lineWidth / 2,
            height: lineWidth
        ))

        return [
            (blue, BrandColor.googleBlue),
            (arc(45, 135), BrandColor.googleGreen),    // 하단
            (arc(135, 215), BrandColor.googleYellow),  // 좌측
            (arc(215, 315), BrandColor.googleRed),     // 상단 (315~325 는 로고 갭)
        ]
    }
}
