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
public final class AdMobInterstitialAdLoader: NSObject, InterstitialAdControlling, FullScreenContentDelegate {

    private let adUnitId: String
    private let log = Logger(subsystem: "AppFoundation", category: "AdKitAdMob.Interstitial")

    private var cachedAd: InterstitialAd?
    private var dismissContinuation: CheckedContinuation<Void, Never>?

    public init(adUnitId: String) {
        self.adUnitId = adUnitId
    }

    public var isAdReady: Bool { cachedAd != nil }

    /// 광고 1개를 미리 로드한다. 캐시가 있으면 no-op. 성공·실패와 무관하게
    /// 로드가 끝나면 반환된다. (빈 unit ID = placement 비활성 — no-op)
    public func loadAd() async {
        guard !adUnitId.isEmpty, cachedAd == nil else { return }
        do {
            let ad = try await InterstitialAd.load(with: adUnitId, request: Request())
            ad.fullScreenContentDelegate = self
            cachedAd = ad
            log.info("interstitial cached — unit: \(self.adUnitId)")
        } catch {
            log.warning("interstitial load failed: \(error.localizedDescription)")
        }
    }

    /// 캐시된 광고를 표시하고 닫힐 때 반환된다. 로드된 광고가 없으면
    /// `AdError.notReady` 를 던진다.
    public func present(from presenter: UIViewController) async throws {
        guard let ad = cachedAd else { throw AdError.notReady }
        cachedAd = nil
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            dismissContinuation = continuation
            ad.present(from: presenter)
        }
    }

    // MARK: FullScreenContentDelegate

    public func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        dismissContinuation?.resume()
        dismissContinuation = nil
    }

    public func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        log.warning("interstitial present failed: \(error.localizedDescription)")
        dismissContinuation?.resume()
        dismissContinuation = nil
    }
}
