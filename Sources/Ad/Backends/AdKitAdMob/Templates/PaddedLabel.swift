//
//  PaddedLabel.swift
//  AppFoundation / AdKitAdMob
//
//  텍스트 주위에 inset 패딩을 주는 UILabel — "AD" 배지 등에 쓴다.
//

import UIKit

final class PaddedLabel: UILabel {

    var textInsets = UIEdgeInsets(top: 2, left: 4, bottom: 2, right: 4)

    override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines numberOfLines: Int) -> CGRect {
        let insetRect = bounds.inset(by: textInsets)
        let textRect = super.textRect(forBounds: insetRect, limitedToNumberOfLines: numberOfLines)
        let invertedInsets = UIEdgeInsets(
            top: -textInsets.top,
            left: -textInsets.left,
            bottom: -textInsets.bottom,
            right: -textInsets.right
        )
        return textRect.inset(by: invertedInsets)
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: textInsets))
    }
}
