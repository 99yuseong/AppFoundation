//
//  AdMobNativeAdLoader.swift
//  AppFoundation / AdKitAdMob
//
//  GMA 의 delegate 기반 AdLoader 를 단발 async 로드로 감싼다. 호출부가 자기
//  주기(예: n초마다 1개)를 스스로 굴리며 틱마다 한 개씩 요청하는 placement 에
//  쓴다. 캐시·주기 로직이 필요하면 Cached/Persistent/Rotating 로더를 쓴다.
//

import UIKit
import GoogleMobileAds
import AdKit
import os

/// 지정 unit 의 `NativeAd` 1개를 async 로 로드한다.
@MainActor
public final class AdMobNativeAdLoader: NSObject, NativeAdLoaderDelegate {

    private let adUnitId: String
    private let options: [GADAdLoaderOptions]
    private let log = Logger(subsystem: "AppFoundation", category: "AdKitAdMob.Native")

    /// 로드 진행 중에만 강참조로 붙든다 (놓으면 delegate 가 불리기 전에 SDK
    /// 로더가 해제된다).
    private var adLoader: AdLoader?
    private var continuation: CheckedContinuation<NativeAd, Error>?

    public init(adUnitId: String, options: [GADAdLoaderOptions] = []) {
        self.adUnitId = adUnitId
        self.options = options
    }

    /// 네이티브 광고 1개를 로드한다. 광고 클릭 처리를 위해 루트 뷰컨트롤러를
    /// 받을 수 있다. 실패는 `AdError.loadFailed` 로 던진다.
    public func load(rootViewController: UIViewController? = nil) async throws -> NativeAd {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let loader = AdLoader(
                adUnitID: adUnitId,
                rootViewController: rootViewController,
                adTypes: [.native],
                options: options
            )
            loader.delegate = self
            self.adLoader = loader
            loader.load(Request())
        }
    }

    // MARK: NativeAdLoaderDelegate

    public func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        finish(.success(nativeAd))
    }

    public func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        log.warning("native ad load failed: \(error.localizedDescription)")
        finish(.failure(AdError.loadFailed(underlying: error)))
    }

    private func finish(_ result: Result<NativeAd, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        self.adLoader = nil
        continuation.resume(with: result)
    }
}
