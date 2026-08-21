//
//  AdMobNativeAdPersistentLoader.swift
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

@MainActor
public final class AdMobNativeAdPersistentLoader: NSObject, ObservableObject, NativeAdPersistentLoading {

    /// 로더 설정. 기본값(`Configuration()`)이 곧 `.default` — 두 표기가 항상 같다.
    public struct Configuration {

        /// 캐시 유효기간(초). nil 이면 만료 없음.
        public let cacheDuration: TimeInterval?
        /// true 면 이미지 에셋을 내려받지 않는다 (텍스트 중심 배너의 대역폭 절약).
        public let isImageLoadingDisabled: Bool

        public init(
            cacheDuration: TimeInterval? = 15.0,
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

        public static var `default`: Self { Configuration() }
    }

    @Published public private(set) var currentAd: NativeAd?
    @Published public private(set) var shouldShowAd: Bool = false

    private var shouldRemoveAds: Bool = false

    private let adUnitId: String
    private let configuration: Configuration
    private let log = Logger(subsystem: "AppFoundation", category: "AdKitAdMob.PersistentNative")
    private var adLoader: AdLoader?

    private var conditionObservationTask: Task<Void, Never>?
    private var lastLoadedTime: ContinuousClock.Instant?
    private let clock = ContinuousClock()
    private var loadingContinuation: CheckedContinuation<Void, Never>?
    private var lastLoadError: Error?
    /// 중복 loadAd() 합류 게이트 — 에러도 합류자 전원에게 전파된다 (AdKit).
    private let loadGate = SingleFlightGate()

    private var isCacheValid: Bool {
        guard currentAd != nil, let lastLoadedTime else { return false }
        guard let duration = configuration.cacheDuration else { return true }
        return clock.now - lastLoadedTime < .seconds(duration)
    }

    /// 만료 광고 제거 — 게시 값이므로 제거 시 표시 상태도 함께 갱신된다.
    private func removeExpiredCache() {
        if currentAd != nil, !isCacheValid {
            currentAd = nil
            lastLoadedTime = nil
            updateVisibility()
        }
    }

    // MARK: - Dependency

    private let conditionChecker: AdConditionChecker

    public init(
        adUnitId: String,
        configuration: Configuration = .default,
        conditionChecker: AdConditionChecker = AlwaysAllowAdConditionChecker()
    ) {
        self.adUnitId = adUnitId
        self.configuration = configuration
        self.conditionChecker = conditionChecker
        super.init()
        setUpLoader()
        // 조건 관찰은 첫 loadAd() 에서 시작한다 — init 에서 Task 를 만들지 않는다.
    }

    deinit {
        loadingContinuation?.resume()
        loadingContinuation = nil
        conditionObservationTask?.cancel()
        conditionObservationTask = nil
    }

    /// 광고를 로드해 게시한다. 조건 확인을 기다렸다가 숨김 상태면 no-op,
    /// 유효한 캐시가 있으면 no-op, 진행 중이면 합류해 같은 결과(에러 포함)를
    /// 기다린다. no-fill 은 `AdError.noFill`, 그 외 실패는 `AdError.loadFailed`.
    public func loadAd() async throws {
        guard !adUnitId.isEmpty else { return }
        startObservingConditionChangesIfNeeded()

        if !conditionChecker.isChecked {
            await conditionChecker.waitUntilCheck()
        }
        // 조건 확인 직후 현재 상태를 스냅샷으로 반영한다 — 스트림 방출에 기대지 않는다.
        shouldRemoveAds = conditionChecker.isAdHidden
        if shouldRemoveAds {
            updateVisibility()
            return
        }

        removeExpiredCache()
        guard currentAd == nil else { return }

        try await loadGate.run { [weak self] in
            guard let self else { return }
            self.removeExpiredCache()
            guard self.currentAd == nil else { return }

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
        updateVisibility()
    }

    /// 표시 여부는 파생값 — "유효한 광고가 있고, 숨김 조건이 아니다".
    /// 별도 Bool 두 개를 손으로 동기화하지 않는다 (경합의 원인이었다).
    private func updateVisibility() {
        shouldShowAd = (currentAd != nil) && !shouldRemoveAds
    }
}

extension AdMobNativeAdPersistentLoader {

    private func setUpLoader() {
        adLoader = AdLoader(
            adUnitID: adUnitId,
            rootViewController: nil,
            adTypes: [.native],
            options: configuration.options
        )
        adLoader?.delegate = self
    }

    /// 조건 관찰 시작 (1회). checker 를 별도 캡처하고 iteration 안에서만 self 를
    /// 강참조한다 — 루프 밖 `guard let self` 는 무한 스트림 동안 로더를 붙들어
    /// Task↔로더 순환 참조(deinit 불가)를 만든다.
    private func startObservingConditionChangesIfNeeded() {
        guard conditionObservationTask == nil else { return }
        let checker = conditionChecker
        conditionObservationTask = Task { [weak self] in
            for await shouldRemove in checker.shouldHideAds {
                guard let self else { return }
                self.handleConditionChange(shouldRemove: shouldRemove)
            }
        }
    }

    private func handleConditionChange(shouldRemove: Bool) {
        shouldRemoveAds = shouldRemove
        updateVisibility()
        if shouldRemove {
            log.info("광고 숨김 (조건 변화)")
        } else {
            log.info("광고 표시 가능 (조건 변화)")
        }
    }
}

// MARK: - AdLoaderDelegate, NativeAdLoaderDelegate

extension AdMobNativeAdPersistentLoader: AdLoaderDelegate, NativeAdLoaderDelegate {

    public func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        log.info("native ad loaded — '\(nativeAd.headline ?? "unknown")'")
        lastLoadedTime = clock.now
        currentAd = nativeAd
        updateVisibility()
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
