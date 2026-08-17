//
//  AdMobPersistentNativeAdLoader.swift
//  AppFoundation / AdKitAdMob
//
//  화면에 상주하는 네이티브 광고(하단 배너 등)용 로더. 광고 1개를 로드해
//  `currentAd` 로 게시하고, `AdConditionChecker` 의 숨김 상태 변화(구독 시작 등)에
//  반응해 `shouldShowAd` 를 갱신한다. 뷰는 두 @Published 값만 관찰하면 된다.
//

import Foundation
import GoogleMobileAds
import Combine
import AdKit
import os

/// `AdMobPersistentNativeAdLoader` 설정.
public struct PersistentNativeAdConfiguration {

    /// 캐시 유효기간(초). nil 이면 만료 없음.
    public let cacheDuration: TimeInterval?
    /// true 면 이미지 에셋을 내려받지 않는다 (텍스트 중심 배너의 대역폭 절약).
    public let isImageLoadingDisabled: Bool

    public init(
        cacheDuration: TimeInterval? = nil,
        isImageLoadingDisabled: Bool = false
    ) {
        self.cacheDuration = cacheDuration
        self.isImageLoadingDisabled = isImageLoadingDisabled
    }

    var options: [GADAdLoaderOptions] {
        let nativeOptions = NativeAdImageAdLoaderOptions()
        nativeOptions.isImageLoadingDisabled = isImageLoadingDisabled
        return [nativeOptions]
    }

    public static var `default`: Self {
        PersistentNativeAdConfiguration(cacheDuration: 15.0)
    }
}

@MainActor
public final class AdMobPersistentNativeAdLoader: NSObject, ObservableObject {

    @Published public private(set) var currentAd: NativeAd?
    @Published public private(set) var shouldShowAd: Bool = false

    private var shouldRemoveAds: Bool = false

    private let adUnitId: String
    private let configuration: PersistentNativeAdConfiguration
    private let log = Logger(subsystem: "AppFoundation", category: "AdKitAdMob.PersistentNative")
    private var adLoader: AdLoader?

    private var conditionObservationTask: Task<Void, Never>?
    private var lastLoadedTime: Date?
    private var loadingContinuation: CheckedContinuation<Void, Never>?

    private var isCacheValid: Bool {
        guard currentAd != nil else { return false }
        guard let lastLoadedTime else { return false }
        guard let duration = configuration.cacheDuration else { return true }
        return Date().timeIntervalSince(lastLoadedTime) < duration
    }

    // MARK: - Dependency

    private let conditionChecker: AdConditionChecker

    public init(
        adUnitId: String,
        configuration: PersistentNativeAdConfiguration = .default,
        conditionChecker: AdConditionChecker = AlwaysAllowAdConditionChecker()
    ) {
        self.adUnitId = adUnitId
        self.configuration = configuration
        self.conditionChecker = conditionChecker
        super.init()
        setUpLoader()
        startObservingConditionChanges()
    }

    deinit {
        loadingContinuation?.resume()
        loadingContinuation = nil
        conditionObservationTask?.cancel()
        conditionObservationTask = nil
    }

    /// 광고를 로드해 게시한다. 조건 확인을 기다렸다가 숨김 상태면 no-op,
    /// 유효한 캐시가 있으면 no-op, 진행 중이면 합류한다.
    public func loadAds() async {
        guard !adUnitId.isEmpty else { return }

        if !conditionChecker.isChecked {
            await conditionChecker.waitUntilCheck()
        }
        if conditionChecker.isAdHidden { return }

        guard !isCacheValid else { return }
        guard loadingContinuation == nil else { return }

        await withCheckedContinuation { continuation in
            loadingContinuation = continuation
            adLoader?.load(Request())
        }

        // 로드 직후 노출 — 짧은 stagger 로 레이아웃 튐을 줄인다.
        if !shouldShowAd && !shouldRemoveAds {
            try? await Task.sleep(for: .milliseconds(300))
            shouldShowAd = true
        }
    }
}

extension AdMobPersistentNativeAdLoader {

    private func setUpLoader() {
        adLoader = AdLoader(
            adUnitID: adUnitId,
            rootViewController: nil,
            adTypes: [.native],
            options: configuration.options
        )
        adLoader?.delegate = self
    }

    private func startObservingConditionChanges() {
        conditionObservationTask = Task { [weak self] in
            guard let self else { return }
            for await shouldRemove in self.conditionChecker.shouldHideAds {
                handleConditionChange(shouldRemove: shouldRemove)
            }
        }
    }

    private func handleConditionChange(shouldRemove: Bool) {
        shouldRemoveAds = shouldRemove
        if shouldRemove {
            shouldShowAd = false
            log.info("광고 숨김 (조건 변화)")
        } else {
            log.info("광고 표시 가능 (조건 변화)")
        }
    }
}

// MARK: - AdLoaderDelegate, NativeAdLoaderDelegate

extension AdMobPersistentNativeAdLoader: AdLoaderDelegate, NativeAdLoaderDelegate {

    public func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        log.info("native ad loaded — '\(nativeAd.headline ?? "unknown")'")
        lastLoadedTime = .now
        currentAd = nativeAd
    }

    public func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: any Error) {
        log.warning("native ad load failed: \(error.localizedDescription)")
    }

    public func adLoaderDidFinishLoading(_ adLoader: AdLoader) {
        loadingContinuation?.resume()
        loadingContinuation = nil
    }
}
