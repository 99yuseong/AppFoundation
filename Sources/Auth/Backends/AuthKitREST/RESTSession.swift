//
//  RESTSession.swift
//  AppFoundation / AuthKit (Backends 계층)
//

import Foundation

/// 자체 서버가 발급한 세션. 표준 계약의 교환 응답
/// `{"access_token","refresh_token"?,"uid","email"?}` 과 일치한다.
public struct RESTSession: Sendable, Codable, Equatable {

    public let accessToken: String
    public let refreshToken: String?
    public let uid: String
    public let email: String?

    public init(
        accessToken: String,
        refreshToken: String? = nil,
        uid: String,
        email: String? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.uid = uid
        self.email = email
    }

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case uid
        case email
    }
}
