//
//  ATTAuthorizationStatus.swift
//  AppFoundation / AdKit
//

/// 호출부가 행동을 결정하는 데 쓰는 ATT 상태. `restricted`(기기 정책 —
/// 다시 물어도 소용없음)는 `denied` 로 접는다.
public enum ATTAuthorizationStatus: Sendable {
    case notDetermined
    case authorized
    case denied
}
