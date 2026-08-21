//
//  ATTAuthorizationRawStatus.swift
//  AppFoundation / AdKit
//

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
