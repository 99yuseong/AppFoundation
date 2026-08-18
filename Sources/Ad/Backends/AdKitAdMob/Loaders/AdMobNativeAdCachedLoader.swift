//
//  AdMobNativeAdCachedLoader.swift
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

@MainActor
public final class AdMobNativeAdCachedLoader: NSObject, ObservableObject, NativeAdCachedLoading {

    /// 로더 설정. 기본값(`Configuration()`)이 곧 `.default` — 두 표기가 항상 같다.
    public struct Configuration {

        /// 캐시 유효기간(초). nil 이면 만료 없음.
        public let cacheDuration: TimeInterval?
        public let shouldRequestMultipleImages: Bool
        public let mediaAspectRatio: MediaAspectRatio
        /// 영상 광고를 음소거 상태로 시작할지 (전면형 광고 권장 true).
        public let startsVideoMuted: Bool

        public init(
            cacheDuration: TimeInterval? = 60.0,
            shouldRequestMultipleImages: Bool = false,
            mediaAspectRatio: MediaAspectRatio = .landscape,
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

        public static var `default`: Self { Configuration() }
    }

    @Published public private(set) var cachedAd: NativeAd?

    private let adUnitId: String
    private let configuration: Configuration
    private let log = Logger(subsystem: "AppFoundation", category: "AdKitAdMob.CachedNative")
    private var adLoader: AdLoader?

    private var lastLoadedTime: ContinuousClock.Instant?
    private let clock = ContinuousClock()
    private var loadingContinuation: CheckedContinuation<Void, Never>?
    private var lastLoadError: Error?
    /// 중복 loadAd() 합류 게이트 — 에러도 합류자 전원에게 전파된다 (AdKit).
    private let loadGate = SingleFlightGate()

    private var isCacheValid: Bool {
        guard cachedAd != nil, let lastLoadedTime else { return false }
        guard let duration = configuration.cacheDuration else { return true }
        return clock.now - lastLoadedTime < .seconds(duration)
    }

    /// 만료 캐시 제거 — 만료 검사는 loadAd/isAdReady/consumeAd 모든 경계에서
    /// 동일하게 적용된다 (만료 광고는 어느 경로로도 노출되지 않는다).
    private func removeExpiredCache() {
        if cachedAd != nil, !isCacheValid {
            cachedAd = nil
            lastLoadedTime = nil
        }
    }

    // MARK: - Initialization

    public init(
        adUnitId: String,
        configuration: Configuration = .default
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
    /// 합류해 같은 결과(에러 포함)를 기다린다. no-fill 은 `AdError.noFill`,
    /// 그 외 실패는 `AdError.loadFailed`.
    public func loadAd() async throws {
        guard !adUnitId.isEmpty else { return }
        removeExpiredCache()
        guard cachedAd == nil else { return }

        try await loadGate.run { [weak self] in
            guard let self else { return }
            self.removeExpiredCache()
            guard self.cachedAd == nil else { return }

            self.lastLoadError = nil
            await withCheckedContinuation { continuation in
                self.loadingContinuation = continuation
                self.adLoader?.load(Request())
            }
            // 만료 광고가 남아 있었더라도 이번 요청의 실패는 그대로 전파한다.
            if let error = self.lastLoadError {
                throw AdError(gmaLoadError: error)
            }
        }
    }

    /// 광고가 준비되었는지 확인 (만료 캐시는 제외).
    public var isAdReady: Bool {
        removeExpiredCache()
        return cachedAd != nil
    }

    /// 캐시된 광고를 소비하고 반환한다 (1회 소비 — 꺼내면 캐시가 비워진다).
    /// nil = 미보유 또는 만료.
    public func consumeAd() -> NativeAd? {
        removeExpiredCache()
        let ad = cachedAd
        cachedAd = nil
        lastLoadedTime = nil
        return ad
    }
}

// MARK: - Private Methods

extension AdMobNativeAdCachedLoader {

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

extension AdMobNativeAdCachedLoader: AdLoaderDelegate, NativeAdLoaderDelegate {

    public func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        log.info("native ad cached — '\(nativeAd.headline ?? "unknown")'")
        lastLoadedTime = clock.now
        cachedAd = nativeAd
    }

    public func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: any Error) {
        log.warning("native ad load failed: \(error.localizedDescription)")
        lastLoadError = error
    }

    public func adLoaderDidFinishLoading(_ adLoader: AdLoader) {
        loadingContinuation?.resume()
        loadingContinuation = nil
    }
}
