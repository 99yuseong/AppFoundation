//
//  SignOutScope.swift
//  AppFoundation / AuthKit
//

/// 로그아웃 범위.
public enum SignOutScope: Sendable {
    /// 이 기기의 세션만 종료.
    case local
    /// 모든 기기의 세션 종료(회원탈퇴 마무리 등).
    case global
}
