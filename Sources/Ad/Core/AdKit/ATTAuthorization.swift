//
//  ATTAuthorization.swift
//  AppFoundation / AdKit
//
//  App Tracking Transparency 공개 진입점. ATT 는 광고 SDK 를 위해 존재하므로
//  AppTrackingTransparency import 를 AdKit 이 소유한다 — 앱 온보딩은 프레임워크를
//  직접 만지지 않고 이것을 호출한다. 광고 SDK 시작과 독립적이다: 프롬프트는
//  온보딩 중, SDK 시작 전에 뜰 수 있다.
//

import Foundation
import AppTrackingTransparency
import os

/// 호출부가 행동을 결정하는 데 쓰는 ATT 상태. `restricted`(기기 정책 —
/// 다시 물어도 소용없음)는 `denied` 로 접는다.
public enum ATTAuthorizationStatus: Sendable {
    case notDetermined
    case authorized
    case denied
}

/// `ATTrackingManager` 를 1:1 로 비추는 **접지 않은** ATT 상태.
///
/// `ATTAuthorizationStatus` 는 행동(프롬프트 여부)을 결정하는 타입이라
/// `restricted` 와 `denied` 가 같은 결정이지만, 분석(analytics)은 구분이 필요하다:
/// `restricted` 는 기기 정책(스크린 타임, MDM)이지 사용자의 거부가 아니어서
/// 합쳐 버리면 opt-out 비율을 잘못 읽는다.
public enum ATTAuthorizationRawStatus: Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

/// App Tracking Transparency 진입점.
public enum ATTAuthorization {

    private static let log = Logger(subsystem: "AppFoundation", category: "AdKit.ATT")

    /// 프롬프트 없이 현재 상태를 읽는다. 온보딩 재개 로직은 `notDetermined` 로
    /// ATT 단계 재진입 여부를 결정한다.
    public static var status: ATTAuthorizationStatus {
        switch ATTrackingManager.trackingAuthorizationStatus {
        case .notDetermined:        return .notDetermined
        case .authorized:           return .authorized
        case .denied, .restricted:  return .denied
        @unknown default:           return .denied
        }
    }

    /// 프롬프트 없이, 접지도 않은 현재 상태 — 분석 리포팅 전용.
    /// 행동 결정은 계속 ``status`` 를 쓴다.
    public static var rawStatus: ATTAuthorizationRawStatus {
        switch ATTrackingManager.trackingAuthorizationStatus {
        case .notDetermined:    return .notDetermined
        case .authorized:       return .authorized
        case .denied:           return .denied
        case .restricted:       return .restricted
        @unknown default:       return .denied
        }
    }

    /// ATT 권한을 요청한다. `notDetermined` 일 때만 프롬프트가 뜨고, 그 외에는
    /// 현재 상태가 즉시 반환된다. 추적 허용 여부를 돌려준다.
    @discardableResult
    public static func request() async -> Bool {
        let status = await ATTrackingManager.requestTrackingAuthorization()
        switch status {
        case .notDetermined: log.warning("ATT 미결정")
        case .restricted:    log.warning("ATT 제한됨")
        case .denied:        log.warning("ATT 거부됨")
        case .authorized:    log.info("ATT 허용됨")
        @unknown default:    log.warning("ATT 알 수 없는 상태")
        }
        return status == .authorized
    }
}
