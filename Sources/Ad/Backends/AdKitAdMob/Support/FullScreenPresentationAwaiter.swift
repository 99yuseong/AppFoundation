//
//  FullScreenPresentationAwaiter.swift
//  AppFoundation / AdKitAdMob
//
//  전면·보상형 공용: 광고의 fullScreenContentDelegate 가 되어 present 를
//  시작하고 dismiss(또는 표시 실패)까지 suspend 한다.
//
//  present 호출마다 새 인스턴스를 만든다 — 로더가 delegate 를 겸하며 단일
//  continuation 슬롯을 공유하면, 표시 중 재호출이 슬롯을 덮어써 이전 호출이
//  영구 suspend 될 수 있다 (호출별 인스턴스가 그 계열의 버그를 제거한다).
//  GMA 의 delegate 참조는 weak 이므로 await 하는 동안 호출부 스택이 이
//  인스턴스를 강참조로 붙들어야 한다 (로컬 변수로 충분).
//

import GoogleMobileAds
import AdKit

@MainActor
final class FullScreenPresentationAwaiter: NSObject, FullScreenContentDelegate {

    private var continuation: CheckedContinuation<Void, Never>?
    private var presentError: Error?

    /// `ad` 의 delegate 가 된 뒤 `start` 로 표시를 시작하고, 닫힐 때까지
    /// suspend 한다. SDK 가 표시 실패를 보고하면
    /// `AdError.presentationFailed` 를 던진다.
    func present(_ ad: FullScreenPresentingAd, start: @MainActor () -> Void) async throws {
        ad.fullScreenContentDelegate = self
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            continuation = c
            start()
        }
        if let presentError {
            throw AdError.presentationFailed(underlying: presentError)
        }
    }

    // MARK: FullScreenContentDelegate

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        finish()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        presentError = error
        finish()
    }

    private func finish() {
        continuation?.resume()
        continuation = nil
    }
}
