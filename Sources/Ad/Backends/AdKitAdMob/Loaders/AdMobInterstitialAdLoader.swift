//
//  AdMobInterstitialAdLoader.swift
//  AppFoundation / AdKitAdMob
//
//  전면 광고 1개를 미리 로드해 두었다가(cache-one) 전체 화면으로 표시한다.
//  프레젠테이션 UI 는 SDK 가 전부 소유한다. placement 하나당 인스턴스 하나를
//  만든다 (unit ID 주입).
//

import UIKit
import GoogleMobileAds
import AdKit
import os

@MainActor
public final class AdMobInterstitialAdLoader: InterstitialAdLoading {

    private let adUnitId: String
    private let log = Logger(subsystem: "AppFoundation", category: "AdKitAdMob.Interstitial")

    /// load-once 캐시 + TTL + in-flight 합류 (`SingleFlightCache`, AdKit).
    private let cache: SingleFlightCache<InterstitialAd>
    private var isPresenting = false

    /// - Parameters:
    ///   - adUnitId: placement 의 unit ID. 빈 값 = placement 비활성 (전체 no-op).
    ///   - cacheDuration: preload 캐시 유효기간(초). GMA 광고는 로드 후 약 1시간
    ///     만료되므로 기본 1시간 — 만료 캐시로 present 가 실패하는 것을 막는다.
    public init(adUnitId: String, cacheDuration: TimeInterval? = 3600) {
        self.adUnitId = adUnitId
        self.cache = SingleFlightCache(
            cacheDuration: cacheDuration.map { .seconds($0) }
        )
    }

    public var isAdReady: Bool { cache.isReady }

    /// 광고 1개를 미리 로드한다. 유효한 캐시가 있으면 no-op, 진행 중이면 합류한다
    /// (에러도 합류 전파). no-fill 은 `AdError.noFill`, 그 외는 `AdError.loadFailed`.
    public func loadAd() async throws {
        guard !adUnitId.isEmpty else { return }
        do {
            try await cache.loadIfNeeded {
                let ad = try await InterstitialAd.load(with: self.adUnitId, request: Request())
                self.log.info("interstitial cached — unit: \(self.adUnitId)")
                return ad
            }
        } catch {
            log.warning("interstitial load failed: \(error.localizedDescription)")
            throw AdError(gmaLoadError: error)
        }
    }

    /// 캐시된 광고를 표시하고 닫힐 때 반환된다. 로드된 광고가 없으면
    /// `AdError.notReady`, 다른 광고 표시 중이면 `AdError.alreadyPresenting`
    /// (캐시 미소비), 표시 시작 실패는 `AdError.presentationFailed`.
    public func present(from presenter: UIViewController) async throws {
        try Task.checkCancellation()
        guard !isPresenting else { throw AdError.alreadyPresenting }
        guard let ad = cache.take() else { throw AdError.notReady }

        // 만료·프레젠테이션 충돌 등은 표시 전에 SDK 검사로 거른다.
        do {
            try ad.canPresent(from: presenter)
        } catch {
            log.warning("interstitial cannot present: \(error.localizedDescription)")
            throw AdError.presentationFailed(underlying: error)
        }

        isPresenting = true
        defer { isPresenting = false }

        let awaiter = FullScreenPresentationAwaiter()
        try await awaiter.present(ad) {
            ad.present(from: presenter)
        }
    }
}
