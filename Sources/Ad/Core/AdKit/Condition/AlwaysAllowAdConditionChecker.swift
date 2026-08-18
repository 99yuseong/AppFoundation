//
//  AlwaysAllowAdConditionChecker.swift
//  AppFoundation / AdKit
//
//  기본 체커: 광고 항상 허용. 구독/원격 게이팅이 생기면 앱 구현체로 교체된다.
//  `shouldHideAds` 스트림은 아무것도 방출하지 않는다 (변화 없음) — 로더는
//  스트림 방출에 기대지 말고 현재 상태 스냅샷을 먼저 적용해야 한다.
//

public struct AlwaysAllowAdConditionChecker: AdConditionChecker {
    public init() {}
    public var isAdHidden: Bool { false }
    public var isChecked: Bool { true }
    public func waitUntilCheck() async {}
    public var shouldHideAds: AsyncStream<Bool> { AsyncStream { _ in } }
}
