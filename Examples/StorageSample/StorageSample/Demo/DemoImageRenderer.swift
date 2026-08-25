//
//  DemoImageRenderer.swift
//  StorageSample
//
//  업로드할 샘플 이미지를 즉석 생성한다 — 사진 권한 없이 리허설을 돌리기 위함.
//  타임스탬프가 박혀 있어 "방금 올린 그 파일"이 표시되는지 눈으로 확인할 수 있다.
//

import UIKit

enum DemoImageRenderer {

    static func makeJPEG() -> Data {
        let size = CGSize(width: 400, height: 400)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let colors = [UIColor.systemIndigo.cgColor, UIColor.systemTeal.cgColor]
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0, 1]
            )!
            context.cgContext.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )

            let text = "R2 리허설\n\(Date().formatted(date: .abbreviated, time: .standard))"
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            (text as NSString).draw(
                in: CGRect(x: 0, y: 160, width: size.width, height: 120),
                withAttributes: [
                    .font: UIFont.boldSystemFont(ofSize: 28),
                    .foregroundColor: UIColor.white,
                    .paragraphStyle: paragraph,
                ]
            )
        }
        return image.jpegData(compressionQuality: 0.85)!
    }
}
