//
//  AdMobRotatingNativeAdLoader.swift
//  AppFoundation / AdKitAdMob
//
//  일정 주기로 광고를 교체하는 로테이션 로더. 한 번에 여러 개를 받아
//  (MultipleAdsAdLoaderOptions) 캐시에서 하나씩 꺼내 게시하고, 캐시가 비면
//  다시 로드한다. `AdConditionChecker` 의 숨김 상태에 반응해 로테이션을
//  멈추고/재개한다.
//

import Foundation
import GoogleMobileAds
import Combine
import AdKit
import os

/// `AdMobRotatingNativeAdLoader` 설정.
public struct RotatingNativeAdConfiguration {

    /// 광고 교체 주기(초).
    public let adRotationInterval: TimeInterval
    /// 한 번의 로드로 받아둘 광고 수.
    public let numberOfAds: Int
    /// true 면 이미지 에셋을 내려받지 않는다 (텍스트 라인 광고 권장).
    public let isImageLoadingDisabled: Bool

    public init(
        adRotationInterval: TimeInterval,
        numberOfAds: Int,
        isImageLoadingDisabled: Bool = true
    ) {
        self.adRotationInterval = adRotationInterval
        self.numberOfAds = numberOfAds
        self.isImageLoadingDisabled = isImageLoadingDisabled
    }

    var options: [GADAdLoaderOptions] {
        let nativeOptions = NativeAdImageAdLoaderOptions()
        nativeOptions.isImageLoadingDisabled = isImageLoadingDisabled

        let multipleAdOptions = MultipleAdsAdLoaderOptions()
        multipleAdOptions.numberOfAds = numberOfAds

        return [nativeOptions, multipleAdOptions]
    }

    public static let `default`: RotatingNativeAdConfiguration = .init(
        adRotationInterval: 20,
        numberOfAds: 2
    )
}

@MainActor
public final class AdMobRotatingNativeAdLoader: NSObject, ObservableObject {

    @Published public private(set) var currentAd: NativeAd?
    @Published public private(set) var shouldRemoveAds: Bool = false

    private let adUnitId: String
    private let configuration: RotatingNativeAdConfiguration
    private let log = Logger(subsystem: "AppFoundation", category: "AdKitAdMob.RotatingNative")
    private var adLoader: AdLoader?

    private var rotationTask: Task<Void, Never>?
    private var conditionObservationTask: Task<Void, Never>?
    private var cachedNativeAds: [NativeAd] = []
    private var loadingContinuation: CheckedContinuation<Void, Never>?

    // MARK: - Dependency

    private let conditionChecker: AdConditionChecker

    public init(
        adUnitId: String,
        configuration: RotatingNativeAdConfiguration = .default,
        conditionChecker: AdConditionChecker = AlwaysAllowAdConditionChecker()
    ) {
        self.adUnitId = adUnitId
        self.configuration = configuration
        self.conditionChecker = conditionChecker
        super.init()
        setUpLoader()
    }

    deinit {
        loadingContinuation?.resume()
        loadingContinuation = nil
        rotationTask?.cancel()
        rotationTask = nil
        conditionObservationTask?.cancel()
        conditionObservationTask = nil
    }

    /// 조건 관찰을 시작한다. 광고 표시 가능 상태가 되면 로테이션이 시작된다.
    public func observeCondition() {
        guard !adUnitId.isEmpty else { return }
        startObservingConditionChanges()
    }

    private func startRotation() {
        rotationTask?.cancel()
        rotationTask = makeRotationTask()
    }

    private func stopRotation() {
        rotationTask?.cancel()
        rotationTask = nil
    }
}

extension AdMobRotatingNativeAdLoader {

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
            log.info("광고 숨김 (조건 변화) — 로테이션 중지")
            stopRotation()
        } else {
            log.info("광고 표시 가능 (조건 변화) — 로테이션 시작")
            startRotation()
        }
    }
}

extension AdMobRotatingNativeAdLoader {

    private func makeRotationTask() -> Task<Void, Never> {
        Task { [weak self] in
            guard let self else { return }

            if !conditionChecker.isChecked {
                await conditionChecker.waitUntilCheck()
            }
            if conditionChecker.isAdHidden { return }

            await self.publishAd()

            let timer = Timer.publish(
                every: self.configuration.adRotationInterval,
                on: .main,
                in: .common
            ).autoconnect()

            for await _ in timer.values {
                if Task.isCancelled { break }
                if self.conditionChecker.isAdHidden { break }
                await self.publishAd()
            }
        }
    }

    private func publishAd() async {
        if cachedNativeAds.isEmpty { await loadAds() }

        if !cachedNativeAds.isEmpty {
            currentAd = cachedNativeAds.removeFirst()
        }
    }

    private func loadAds() async {
        guard loadingContinuation == nil else { return }

        return await withCheckedContinuation { continuation in
            self.loadingContinuation = continuation
            adLoader?.load(Request())
        }
    }
}

// MARK: - AdLoaderDelegate, NativeAdLoaderDelegate

extension AdMobRotatingNativeAdLoader: AdLoaderDelegate, NativeAdLoaderDelegate {

    public func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        cachedNativeAds.append(nativeAd)
    }

    public func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: any Error) {
        log.warning("native ad load failed: \(error.localizedDescription)")
    }

    public func adLoaderDidFinishLoading(_ adLoader: AdLoader) {
        log.info("rotation batch loaded — \(self.cachedNativeAds.count)개")
        loadingContinuation?.resume()
        loadingContinuation = nil
    }
}
