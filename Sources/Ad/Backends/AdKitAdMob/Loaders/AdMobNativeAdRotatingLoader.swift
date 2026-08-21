//
//  AdMobNativeAdRotatingLoader.swift
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

@MainActor
public final class AdMobNativeAdRotatingLoader: NSObject, ObservableObject, NativeAdRotatingLoading {

    /// 로더 설정. 기본값(`Configuration()`)이 곧 `.default` — 두 표기가 항상 같다.
    public struct Configuration {

        /// 광고 교체 주기(초).
        public let adRotationInterval: TimeInterval
        /// 한 번의 로드로 받아둘 광고 수.
        public let numberOfAds: Int
        /// true 면 이미지 에셋을 내려받지 않는다 (텍스트 라인 광고 권장).
        public let isImageLoadingDisabled: Bool

        public init(
            adRotationInterval: TimeInterval = 20,
            numberOfAds: Int = 2,
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

        public static var `default`: Self { Configuration() }
    }

    @Published public private(set) var currentAd: NativeAd?
    @Published public private(set) var shouldShowAd: Bool = false

    private let adUnitId: String
    private let configuration: Configuration
    private let log = Logger(subsystem: "AppFoundation", category: "AdKitAdMob.RotatingNative")
    private var adLoader: AdLoader?

    private var rotationTask: Task<Void, Never>?
    private var conditionObservationTask: Task<Void, Never>?
    private var cachedNativeAds: [NativeAd] = []
    private var loadingContinuation: CheckedContinuation<Void, Never>?
    /// 배치 로드 합류 게이트 (AdKit).
    private let loadGate = SingleFlightGate()

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
    }

    deinit {
        loadingContinuation?.resume()
        loadingContinuation = nil
        rotationTask?.cancel()
        rotationTask = nil
        conditionObservationTask?.cancel()
        conditionObservationTask = nil
    }

    /// 로테이션을 시작한다 — 조건 확인 후 즉시 게시·주기 교체를 시작하고,
    /// 이후 조건 변화(구독 시작 등)에 반응한다. 중복 호출은 no-op (idempotent).
    public func start() {
        guard !adUnitId.isEmpty else { return }
        guard conditionObservationTask == nil else { return }
        startObservingConditionChanges()
        // 기본 체커(AlwaysAllow)는 스트림이 아무것도 방출하지 않으므로,
        // 변화 구독과 별개로 현재 상태 기준으로 즉시 시작한다.
        startRotation()
    }

    /// 로테이션과 조건 관찰을 중지한다.
    public func stop() {
        conditionObservationTask?.cancel()
        conditionObservationTask = nil
        stopRotation()
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

extension AdMobNativeAdRotatingLoader {

    private func setUpLoader() {
        adLoader = AdLoader(
            adUnitID: adUnitId,
            rootViewController: nil,
            adTypes: [.native],
            options: configuration.options
        )
        adLoader?.delegate = self
    }

    /// checker 를 별도 캡처하고 iteration 안에서만 self 를 강참조한다 —
    /// 루프 밖 `guard let self` 는 무한 스트림 동안 로더를 붙들어
    /// Task↔로더 순환 참조(deinit 불가)를 만든다.
    private func startObservingConditionChanges() {
        let checker = conditionChecker
        conditionObservationTask = Task { [weak self] in
            for await shouldRemove in checker.shouldHideAds {
                guard let self else { return }
                self.handleConditionChange(shouldRemove: shouldRemove)
            }
        }
    }

    private func handleConditionChange(shouldRemove: Bool) {
        if shouldRemove {
            shouldShowAd = false
            log.info("광고 숨김 (조건 변화) — 로테이션 중지")
            stopRotation()
        } else {
            // 표시 상태는 로테이션이 광고를 실제 게시할 때 켜진다.
            log.info("광고 표시 가능 (조건 변화) — 로테이션 시작")
            startRotation()
        }
    }
}

extension AdMobNativeAdRotatingLoader {

    /// 취소 가능한 sleep 루프로 주기 교체한다. checker·interval 을 별도 캡처하고
    /// iteration 안에서만 self 를 강참조한다 — Timer 스트림/루프 밖 self 캡처는
    /// 로테이션 내내 로더를 붙들어 순환 참조(deinit 불가)를 만든다.
    private func makeRotationTask() -> Task<Void, Never> {
        let checker = conditionChecker
        let interval = configuration.adRotationInterval
        return Task { [weak self] in
            if !checker.isChecked {
                await checker.waitUntilCheck()
            }
            if Task.isCancelled || checker.isAdHidden { return }

            if let self {
                await self.publishAd()
            }

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                if Task.isCancelled || checker.isAdHidden { break }
                guard let self else { break }
                await self.publishAd()
            }
        }
    }

    private func publishAd() async {
        if cachedNativeAds.isEmpty { await loadAds() }

        // 로드 대기(합류 포함) 중 stop/조건 변경으로 취소됐으면 소비·게시하지
        // 않는다 — 취소된 이전 Task 와 새 Task 가 배치를 이중 소비하는 것을 막는다.
        guard !Task.isCancelled else { return }
        guard !cachedNativeAds.isEmpty else { return }

        currentAd = cachedNativeAds.removeFirst()
        // 표시 상태는 광고가 실제로 게시된 뒤에만 켠다 (no-fill 시 빈 슬롯 방지).
        shouldShowAd = true
    }

    private func loadAds() async {
        // 배치 로드 합류 — 진행 중이면 같은 완료를 기다린다. 실패는 로그로
        // 처리한다 (자율 로더 — 다음 주기에 재시도).
        try? await loadGate.run { [weak self] in
            guard let self else { return }
            await withCheckedContinuation { continuation in
                self.loadingContinuation = continuation
                self.adLoader?.load(Request())
            }
        }
    }
}

// MARK: - AdLoaderDelegate, NativeAdLoaderDelegate

extension AdMobNativeAdRotatingLoader: AdLoaderDelegate, NativeAdLoaderDelegate {

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
