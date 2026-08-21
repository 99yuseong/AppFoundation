//
//  AdConditionChecker.swift
//  AppFoundation / AdKit
//
//  "지금 광고를 보여도 되는가" 의 추상화. 구독(광고 제거)·서버 킬스위치가
//  kit 이 이유를 모르는 채 광고를 억제할 수 있게 한다. 기본은 "항상 허용"
//  (`AlwaysAllowAdConditionChecker`) — 앱이 진짜 체커(구독 상태 등)를 주입한다.
//  상주형 로더에 주입한다 — 온디맨드(전면·보상형)는 앱 파사드에서 게이트.
//

import Foundation

/// 광고 표시 가능 여부를 결정한다. 로더에 주입되어 수익화 게이팅(구독,
/// 원격 킬스위치)이 kit 밖에 머문다.
public protocol AdConditionChecker: Sendable {

    /// 지금 광고를 숨겨야 하는가 (true = 광고 없음).
    var isAdHidden: Bool { get }

    /// 최초 조건 확인이 완료됐는가.
    var isChecked: Bool { get }

    /// 최초 조건 확인을 기다린다 (첫 광고 로드 전에 사용).
    func waitUntilCheck() async

    /// 숨김 상태 변화 스트림: `true` → 광고 제거(구독 시작 등),
    /// `false` → 광고 다시 표시.
    var shouldHideAds: AsyncStream<Bool> { get }
}
