//
//  PurchaseIntegration.swift
//  AppFoundation / PurchaseKit
//
//  결제 백엔드에 연결할 분석 도구. 닫힌 enum 이 아니라 String struct — 앱이 kit 수정
//  없이 자체 연동 키를 정의한다 (개방형 provider 원칙). 백엔드가 아는 키는 전용
//  API 로, 모르는 키는 일반 속성으로 매핑한다.
//

public struct PurchaseIntegration: Sendable, Hashable, RawRepresentable {

    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let mixpanel = PurchaseIntegration(rawValue: "mixpanel")
    public static let firebase = PurchaseIntegration(rawValue: "firebase")
    public static let amplitude = PurchaseIntegration(rawValue: "amplitude")
}
