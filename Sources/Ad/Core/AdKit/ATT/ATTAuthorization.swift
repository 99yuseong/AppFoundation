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
