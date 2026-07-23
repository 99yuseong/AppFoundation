//
//  ImageDownsamplerTests.swift
//  AppFoundation / ImageKitTests
//
//  다운샘플링의 핵심 규칙만 검증한다: 긴 변 기준 픽셀 상한·종횡비 유지·확대 금지.
//

import UIKit
import Testing
import ImageKit

@Suite("ImageDownsampler")
struct ImageDownsamplerTests {

    @Test("긴 변 기준 픽셀 상한으로 축소 — 종횡비 유지")
    func downsampleToMaxPixelSize() {
        let data = TestImages.pngData(width: 200, height: 100)

        let image = ImageDownsampler.downsample(data, maxPixelSize: 50)

        #expect(image?.cgImage?.width == 50)
        #expect(image?.cgImage?.height == 25)
    }

    @Test("원본보다 큰 상한 — 확대하지 않는다")
    func noUpscale() {
        let data = TestImages.pngData(width: 200, height: 100)

        let image = ImageDownsampler.downsample(data, maxPixelSize: 400)

        #expect(image?.cgImage?.width == 200)
        #expect(image?.cgImage?.height == 100)
    }

    @Test("손상 데이터 — nil")
    func corruptData() {
        #expect(ImageDownsampler.downsample(Data([0x00, 0x01]), maxPixelSize: 50) == nil)
        #expect(ImageDownsampler.decode(Data([0x00, 0x01])) == nil)
    }
}
