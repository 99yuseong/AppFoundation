//
//  ImageDownsampler.swift
//  AppFoundation / ImageKit
//
//  ImageIO 썸네일 경로 기반 다운샘플링. `UIImage(data:)` 풀 디코드와 달리 원본
//  풀사이즈 비트맵을 만들지 않아 메모리 피크가 목표 크기에 비례한다 — 셀 썸네일에
//  원본 수천 px 이미지를 그대로 올리는 사고를 막는 핵심 도구.
//
//  CPU 작업이다 — 호출자가 메인 액터 밖에서 부른다 (ImageLoader 는 @concurrent
//  경로에서 호출한다).
//

import UIKit
import ImageIO

public enum ImageDownsampler {

    /// 인코딩된 이미지 데이터를 긴 변 기준 `maxPixelSize` **픽셀** 이하로 다운샘플링한다.
    /// 원본이 더 작으면 확대하지 않는다 (ImageIO 썸네일 의미론).
    /// - Parameter scale: 결과 UIImage 의 scale (포인트 크기 = 픽셀 / scale).
    public nonisolated static func downsample(
        _ data: Data,
        maxPixelSize: CGFloat,
        scale: CGFloat = 1
    ) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,   // EXIF 회전 반영
            kCGImageSourceShouldCacheImmediately: true,          // 지금(백그라운드) 즉시 디코드
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ] as [CFString: Any] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }

    /// 다운샘플 없이 디코드만 (maxPixelSize 미지정 경로).
    public nonisolated static func decode(_ data: Data, scale: CGFloat = 1) -> UIImage? {
        UIImage(data: data, scale: scale)
    }
}
