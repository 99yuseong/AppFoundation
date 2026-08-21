//
//  RewardedAdLoading.swift
//  AppFoundation / AdKit
//
//  보상형 광고 백엔드 계약. 백엔드(AdKitAdMob 등)의 로더가 채택하고, 앱 파사드·
//  프리뷰·테스트는 이 계약(또는 Mock/)에만 의존한다.
//

import UIKit

/// 보상형 광고: 사용자가 시청을 선택한 시점에 로드하고 즉시 표시한다.
@MainActor
public protocol RewardedAdLoading {

    /// 로드된 광고가 표시 가능 상태인가.
    var isAdReady: Bool { get }

    /// 광고 1개를 로드한다. 진행 중인 로드가 있으면 합류한다.
    /// no-fill 은 `AdError.noFill`, 그 외 실패는 `AdError.loadFailed` 를 던진다.
    func loadAd() async throws

    /// 캐시된 광고를 표시하고 닫힐 때 반환된다. 반환값은 시청 완료 여부 —
    /// 실제 보상 지급은 서버(SSV)가 결정한다. `userID` 는 SSV 검증 엔드포인트로
    /// 전달할 사용자 식별자 (nil 이면 SSV 미사용).
    /// 로드된 광고가 없으면 `AdError.notReady`, 다른 광고 표시 중이면
    /// `AdError.alreadyPresenting`(캐시 미소비), 표시 시작 실패는
    /// `AdError.presentationFailed` 를 던진다.
    func present(from presenter: UIViewController, userID: String?) async throws -> Bool
}
