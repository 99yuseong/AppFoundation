//
//  AdControlling.swift
//  AppFoundation / AdKit
//
//  전면·보상형 광고의 백엔드 계약. 백엔드(AdKitAdMob 등)의 로더가 채택하고,
//  앱 파사드·프리뷰·테스트는 이 계약(또는 Mocks/)에만 의존한다.
//  네이티브 광고는 SDK 광고 객체를 뷰에 바인딩해야 해서 계약을 여기 두지
//  않는다 — 레이아웃 계약(`NativeAdLayoutUIView`·`NativeAdContent`)만 Core 가
//  소유하고, 로더·호스트는 백엔드 소유다.
//

import UIKit

/// 전면 광고: 미리 로드해 두었다가(cache-one) 전체 화면으로 표시한다.
@MainActor
public protocol InterstitialAdControlling {

    /// 로드된 광고가 표시 가능 상태인가.
    var isAdReady: Bool { get }

    /// 광고 1개를 미리 로드한다. 이미 캐시가 있으면 no-op.
    /// 성공·실패와 무관하게 로드가 끝나면 반환된다.
    func loadAd() async

    /// 캐시된 광고를 표시하고 닫힐 때 반환된다.
    /// 로드된 광고가 없으면 `AdError.notReady` 를 던진다.
    func present(from presenter: UIViewController) async throws
}

/// 보상형 광고: 사용자가 시청을 선택한 시점에 로드하고 즉시 표시한다.
@MainActor
public protocol RewardedAdControlling {

    /// 로드된 광고가 표시 가능 상태인가.
    var isAdReady: Bool { get }

    /// 광고 1개를 로드한다. 진행 중인 로드가 있으면 합류한다.
    func loadAd() async

    /// 캐시된 광고를 표시하고 닫힐 때 반환된다. 반환값은 시청 완료 여부 —
    /// 실제 보상 지급은 서버(SSV)가 결정한다. `userID` 는 SSV 검증 엔드포인트로
    /// 전달할 사용자 식별자 (nil 이면 SSV 미사용).
    /// 로드된 광고가 없으면 `AdError.notReady` 를 던진다.
    func present(from presenter: UIViewController, userID: String?) async throws -> Bool
}
