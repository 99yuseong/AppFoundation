//
//  NativeAdRotatingLoading.swift
//  AppFoundation / AdKit
//
//  네이티브 광고 로더 계약 계열 — 계열 공통 설계는 `NativeAdLoading.swift` 참고.
//

import Combine

/// 주기 로테이션: `start()` 후 `currentAd` 가 주기적으로 교체된다.
/// 자율 동작 로더라 로드 실패는 내부에서 처리한다 (다음 주기에 재시도).
@MainActor
public protocol NativeAdRotatingLoading<Ad>: ObservableObject {
    associatedtype Ad

    /// 게시 중인 광고. 구현체는 @Published 로 충족한다.
    var currentAd: Ad? { get }

    /// 지금 광고를 표시해야 하는가 (false = 슬롯 자체를 숨긴다).
    var shouldShowAd: Bool { get }

    /// 로테이션을 시작한다. 중복 호출은 no-op (idempotent).
    func start()

    /// 로테이션을 중지한다.
    func stop()
}
