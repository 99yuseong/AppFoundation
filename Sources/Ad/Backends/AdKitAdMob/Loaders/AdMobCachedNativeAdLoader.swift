//
//  AdMobCachedNativeAdLoader.swift
//  AppFoundation / AdKitAdMob
//
//  네이티브 광고 1개를 미리 로드해 캐시하고(cache-one), 소비 시점에 1회
//  꺼내 쓰는 로더. 전면형 네이티브 광고(Native-as-Interstitial)의 표준 로더다.
//  캐시에는 유효기간이 있어(AdMob 광고는 로드 후 1시간 만료) 오래된 캐시는
//  무시하고 다시 로드한다. 진행 중인 로드가 있으면 중복 호출은 합류한다.
//

import Foundation
import GoogleMobileAds
import Combine
import AdKit
import os

/// `AdMobCachedNativeAdLoader` 설정.
public struct CachedNativeAdConfiguration {

    /// 캐시 유효기간(초). nil 이면 만료 없음.
    public let cacheDuration: TimeInterval?
    public let shouldRequestMultipleImages: Bool
    public let mediaAspectRatio: MediaAspectRatio
    /// 영상 광고를 음소거 상태로 시작할지 (전면형 광고 권장 true).
    public let startsVideoMuted: Bool

    public init(
        cacheDuration: TimeInterval? = nil,
        shouldRequestMultipleImages: Bool = false,
        mediaAspectRatio: MediaAspectRatio = .any,
        startsVideoMuted: Bool = true
    ) {
        self.cacheDuration = cacheDuration
        self.shouldRequestMultipleImages = shouldRequestMultipleImages
        self.mediaAspectRatio = mediaAspectRatio
        self.startsVideoMuted = startsVideoMuted
    }

    var options: [GADAdLoaderOptions] {
        let imageOptions = NativeAdImageAdLoaderOptions()
        imageOptions.shouldRequestMultipleImages = shouldRequestMultipleImages

        let mediaOptions = NativeAdMediaAdLoaderOptions()
        mediaOptions.mediaAspectRatio = mediaAspectRatio

        let videoOptions = VideoOptions()
        videoOptions.shouldStartMuted = startsVideoMuted

        return [imageOptions, mediaOptions, videoOptions]
    }

    public static var `default`: Self {
        CachedNativeAdConfiguration(
            cacheDuration: 60.0,
            shouldRequestMultipleImages: false,
            mediaAspectRatio: .landscape
        )
    }
}

@MainActor
public final class AdMobCachedNativeAdLoader: NSObject, ObservableObject {

    @Published public private(set) var cachedAd: NativeAd?

    private let adUnitId: String
    private let configuration: CachedNativeAdConfiguration
    private let log = Logger(subsystem: "AppFoundation", category: "AdKitAdMob.CachedNative")
    private var adLoader: AdLoader?

    private var lastLoadedTime: Date?
    private var loadingContinuation: CheckedContinuation<Void, Never>?

    private var isCacheValid: Bool {
        guard cachedAd != nil else { return false }
        guard let lastLoadedTime else { return false }
        guard let duration = configuration.cacheDuration else { return true }
        return Date().timeIntervalSince(lastLoadedTime) < duration
    }

    // MARK: - Initialization

    public init(
        adUnitId: String,
        configuration: CachedNativeAdConfiguration = .default
    ) {
        self.adUnitId = adUnitId
        self.configuration = configuration
        super.init()
        setUpLoader()
    }

    deinit {
        loadingContinuation?.resume()
        loadingContinuation = nil
    }

    // MARK: - Public Methods

    /// 광고 1개를 미리 로드한다. 유효한 캐시가 있으면 no-op, 로드가 진행 중이면
    /// 합류한다. 성공·실패와 무관하게 로드가 끝나면 반환된다.
    public func loadAd() async {
        guard !adUnitId.isEmpty else { return }
        guard !isCacheValid else { return }
        guard loadingContinuation == nil else { return }

        await withCheckedContinuation { continuation in
            loadingContinuation = continuation
            adLoader?.load(Request())
        }
    }

    /// 광고가 준비되었는지 확인.
    public var isAdReady: Bool { cachedAd != nil }

    /// 캐시된 광고를 소비하고 반환한다 (1회 소비 — 꺼내면 캐시가 비워진다).
    public func consumeAd() -> NativeAd? {
        let ad = cachedAd
        cachedAd = nil
        lastLoadedTime = nil
        return ad
    }
}

// MARK: - Private Methods

extension AdMobCachedNativeAdLoader {

    private func setUpLoader() {
        adLoader = AdLoader(
            adUnitID: adUnitId,
            rootViewController: nil,
            adTypes: [.native],
            options: configuration.options
        )
        adLoader?.delegate = self
    }
}

// MARK: - AdLoaderDelegate, NativeAdLoaderDelegate

extension AdMobCachedNativeAdLoader: AdLoaderDelegate, NativeAdLoaderDelegate {

    public func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        log.info("native ad cached — '\(nativeAd.headline ?? "unknown")'")
        lastLoadedTime = .now
        cachedAd = nativeAd
    }

    public func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: any Error) {
        log.warning("native ad load failed: \(error.localizedDescription)")
    }

    public func adLoaderDidFinishLoading(_ adLoader: AdLoader) {
        loadingContinuation?.resume()
        loadingContinuation = nil
    }
}
