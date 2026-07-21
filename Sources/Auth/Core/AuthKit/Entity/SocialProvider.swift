//
//  SocialProvider.swift
//  AppFoundation / AuthKit
//

/// 소셜 로그인 provider. rawValue 는 Supabase `app_metadata.provider` 문자열과 일치한다.
public enum SocialProvider: String, Sendable, Equatable, CaseIterable {
    case apple
    case google
    case kakao
}
