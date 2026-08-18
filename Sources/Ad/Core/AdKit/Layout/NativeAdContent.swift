//
//  NativeAdContent.swift
//  AppFoundation / AdKit
//
//  네이티브 광고 레이아웃 뷰에 전달되는 광고 데이터 스냅샷.
//
//  광고 SDK 타입을 모듈 경계 밖으로 노출하지 않기 위한 DTO — 앱의
//  `NativeAdLayoutUIView` 서브클래스는 광고 SDK 를 import 하지 않고 이 값만
//  쓴다. SDK 광고 → DTO 변환은 각 백엔드(AdKitAdMob 등)가 extension 으로
//  소유한다. (미디어 바인딩·트래킹 연결은 백엔드의 호스트 뷰가 수행)
//

import UIKit

public struct NativeAdContent {

    public let headline: String?
    public let body: String?
    public let iconImage: UIImage?
    public let callToActionText: String?

    /// 미디어(영상/이미지) 콘텐츠가 있는가. true 면 미디어 영역에 표시된다.
    public let hasMediaContent: Bool

    /// 미디어 콘텐츠가 없을 때 대신 쓸 수 있는 첫 번째 광고 이미지.
    public let fallbackImage: UIImage?

    public init(
        headline: String?,
        body: String?,
        iconImage: UIImage?,
        callToActionText: String?,
        hasMediaContent: Bool,
        fallbackImage: UIImage?
    ) {
        self.headline = headline
        self.body = body
        self.iconImage = iconImage
        self.callToActionText = callToActionText
        self.hasMediaContent = hasMediaContent
        self.fallbackImage = fallbackImage
    }
}
