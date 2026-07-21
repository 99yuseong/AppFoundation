//
//  SocialProvider.swift
//  AppFoundation / AuthKit
//

/// 소셜 로그인 provider 식별자. rawValue 는 Supabase `app_metadata.provider` 등
/// 백엔드가 쓰는 provider 문자열과 일치한다.
///
/// 닫힌 enum 이 아니라 String 기반 struct 다 — 앱이 kit 수정 없이 자체 provider 를
/// 정의할 수 있다(`SocialProvider(rawValue: "naver")` 처럼). "사용 가능한 provider
/// 목록"은 전역 나열이 아니라 조립 지점에서 주입한 `AuthService.loginOptions` 가
/// 단일 진실 소스다.
public struct SocialProvider: RawRepresentable, Hashable, Sendable, Codable {

    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let apple = SocialProvider(rawValue: "apple")
    public static let google = SocialProvider(rawValue: "google")
    public static let kakao = SocialProvider(rawValue: "kakao")
}
