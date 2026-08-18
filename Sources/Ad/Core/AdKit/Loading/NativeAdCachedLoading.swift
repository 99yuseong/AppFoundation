//
//  NativeAdCachedLoading.swift
//  AppFoundation / AdKit
//
//  네이티브 광고 로더 계약 계열 — 계열 공통 설계는 `NativeAdLoading.swift` 참고.
//

import Combine

/// cache-one + 1회 소비: 미리 `loadAd()` 로 채워 두고 노출 시점에 `consumeAd()`.
/// 전면형 네이티브 광고의 표준 계약.
@MainActor
public protocol NativeAdCachedLoading<Ad>: ObservableObject {
    associatedtype Ad

    /// 로드된 광고가 소비 가능 상태인가.
    var isAdReady: Bool { get }

    /// 광고 1개를 미리 로드한다. 유효한 캐시가 있으면 no-op, 진행 중인 로드가
    /// 있으면 합류한다 (실패 에러도 합류자 전원에게 동일하게 전파된다).
    func loadAd() async throws

    /// 캐시를 1회 소비한다 (꺼내면 비워진다). nil = 미보유.
    func consumeAd() -> Ad?
}
