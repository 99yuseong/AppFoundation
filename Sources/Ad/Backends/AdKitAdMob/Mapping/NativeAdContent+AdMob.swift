//
//  NativeAdContent+AdMob.swift
//  AppFoundation / AdKitAdMob
//
//  GMA `NativeAd` → SDK 무의존 DTO 변환. 이 변환을 백엔드가 소유해서 앱의
//  레이아웃 뷰는 GoogleMobileAds 를 import 하지 않는다.
//

import GoogleMobileAds
import AdKit

extension NativeAdContent {

    init(nativeAd: NativeAd) {
        self.init(
            headline: nativeAd.headline,
            body: nativeAd.body,
            iconImage: nativeAd.icon?.image,
            callToActionText: nativeAd.callToAction,
            hasMediaContent: nativeAd.mediaContent.aspectRatio > 0,
            fallbackImage: nativeAd.images?.first?.image
        )
    }
}
