//
//  AdError.swift
//  AppFoundation / AdKit
//

/// 광고 도메인 공통 에러. 백엔드(AdMob 등)가 던지고 앱 파사드가 분기한다.
public enum AdError: Error {
    /// 로드는 끝났지만 채울 광고가 없다 (no-fill).
    case noFill
    /// 로드된 광고가 없어 표시할 수 없다.
    case notReady
    /// 광고 SDK 실패 — 원본 에러를 담는다.
    case loadFailed(underlying: Error)
}
