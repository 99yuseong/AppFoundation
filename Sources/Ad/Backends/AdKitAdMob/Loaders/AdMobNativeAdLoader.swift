//
//  AdMobNativeAdLoader.swift
//  AppFoundation / AdKitAdMob
//
//  GMA 의 delegate 기반 AdLoader 를 단발 async 로드로 감싼다. 호출부가 자기
//  주기(예: n초마다 1개)를 스스로 굴리며 틱마다 한 개씩 요청하는 placement 에
//  쓴다. 캐시·주기 로직이 필요하면 Cached/Persistent/Rotating 로더를 쓴다.
//
//  로드 상태(continuation·AdLoader)는 호출별 브리지 인스턴스가 소유한다 —
//  로더가 단일 슬롯으로 들고 있으면 동시 load() 가 서로의 continuation 을
//  덮어써 첫 호출이 영구 suspend 될 수 있다.
//

import UIKit
import GoogleMobileAds
import AdKit
import os

/// 지정 unit 의 `NativeAd` 1개를 async 로 로드한다. 동시 호출은 각자 독립된
/// 요청을 만든다 (단발 API 는 반환 광고를 호출자가 독점해야 하므로 합류하지 않는다).
@MainActor
public final class AdMobNativeAdLoader: NativeAdLoading {

    private let adUnitId: String
    private let options: [GADAdLoaderOptions]
    private let log = Logger(subsystem: "AppFoundation", category: "AdKitAdMob.Native")

    public init(adUnitId: String, options: [GADAdLoaderOptions] = []) {
        self.adUnitId = adUnitId
        self.options = options
    }

    /// 네이티브 광고 1개를 로드한다. 광고 클릭 처리를 위해 루트 뷰컨트롤러를
    /// 받을 수 있다. no-fill 은 `AdError.noFill`, 그 외 실패는 `AdError.loadFailed`.
    /// 빈 unit ID(placement 비활성)는 광고를 반환할 수 없으므로 `AdError.noFill`.
    public func load(rootViewController: UIViewController? = nil) async throws -> NativeAd {
        guard !adUnitId.isEmpty else { throw AdError.noFill }
        do {
            return try await LoadBridge().load(
                adUnitId: adUnitId,
                options: options,
                rootViewController: rootViewController
            )
        } catch {
            log.warning("native ad load failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// 호출별 로드 브리지 — continuation 과 SDK 로더를 이 호출만의 상태로 갖는다.
    /// GMA 의 delegate 참조는 weak 이므로 await 하는 동안 호출부 async frame 이
    /// 이 인스턴스를 강참조로 붙든다 (로컬 사용으로 충분).
    @MainActor
    private final class LoadBridge: NSObject, NativeAdLoaderDelegate {

        private var continuation: CheckedContinuation<NativeAd, Error>?
        /// 로드 진행 중에만 강참조로 붙든다 (놓으면 delegate 가 불리기 전에
        /// SDK 로더가 해제된다).
        private var adLoader: AdLoader?

        func load(
            adUnitId: String,
            options: [GADAdLoaderOptions],
            rootViewController: UIViewController?
        ) async throws -> NativeAd {
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

        func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
            finish(.success(nativeAd))
        }

        func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
            finish(.failure(AdError(gmaLoadError: error)))
        }

        private func finish(_ result: Result<NativeAd, Error>) {
            guard let continuation else { return }
            self.continuation = nil
            self.adLoader = nil
            continuation.resume(with: result)
        }
    }
}
