//
//  HTTPMethod.swift
//  AppFoundation / APIKit
//
//  HTTP 메서드 분류. 닫힌 enum 이 아니라 String 기반 struct 다(`SocialProvider` 선례) —
//  앱/백엔드가 kit 수정 없이 자체 메서드(WebDAV 등)를 정의할 수 있다.
//

/// 엔드포인트가 선언하는 HTTP 메서드. rawValue 는 실제 전송 시 요청 라인에 실리는
/// 대문자 메서드 문자열과 일치한다.
public struct HTTPMethod: RawRepresentable, Hashable, Sendable, CustomStringConvertible {

    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue }

    public static let get    = HTTPMethod(rawValue: "GET")
    public static let post   = HTTPMethod(rawValue: "POST")
    public static let patch  = HTTPMethod(rawValue: "PATCH")
    public static let put    = HTTPMethod(rawValue: "PUT")
    public static let delete = HTTPMethod(rawValue: "DELETE")
}
