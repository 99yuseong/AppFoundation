//
//  NativeAdPersistentLoading.swift
//  AppFoundation / AdKit
//
//  네이티브 광고 로더 계약 계열 — 계열 공통 설계는 `NativeAdLoading.swift` 참고.
//

import Combine

/// 상주 게시: 광고를 로드해 `currentAd` 로 게시하고, 표시 조건 변화에 반응해
/// `shouldShowAd` 를 갱신한다. 뷰는 두 값만 관찰하면 된다.
@MainActor
public protocol NativeAdPersistentLoading<Ad>: ObservableObject {
    associatedtype Ad

    /// 게시 중인 광고. 구현체는 @Published 로 충족한다.
    var currentAd: Ad? { get }

    /// 지금 광고를 표시해야 하는가 (false = 슬롯 자체를 숨긴다).
    var shouldShowAd: Bool { get }

    /// 광고를 로드해 게시한다. 유효한 캐시가 있으면 no-op, 진행 중이면 합류한다.
    func loadAd() async throws
}
