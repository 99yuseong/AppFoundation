//
//  AuthKitError.swift
//  AppFoundation / AuthKit
//
//  Auth 계층이 드러내는 단일 에러 타입.
//  (supabase-swift 가 이미 `AuthError` 를 export 하므로 이름 충돌을 피해 AuthKitError)
//

import Foundation

public enum AuthKitError: Error {

    /// 사용자가 완료 전에 provider 로그인 UI 를 닫음.
    case cancelled

    /// provider 가 presenting 뷰컨트롤러를 필요로 하는데 공급되지 않음.
    case missingPresenter(SocialProvider)

    /// 요청한 타입에 등록된 provider 가 없음(조립 오류).
    case unknownProvider(SocialProvider)

    /// SDK 가 인증에 필요한 credential 없이 반환함
    /// (예: Kakao OIDC 미활성으로 idToken 이 nil, Apple authorizationCode 누락).
    case missingCredential

    /// provider SDK 가 다른 이유로 실패함; 하부 에러를 담는다.
    case providerFailed(SocialProvider, underlying: Error)

    /// 백엔드에서 4xx/5xx 응답이 왔을 때.
    case backendHTTP(statusCode: Int, message: String)

    /// 네트워크 오류로 백엔드 호출에 실패했을 때.
    case backendNetwork(underlying: Error)

    /// 세션이 존재하지 않을 때.
    case sessionNotFound

    /// HTML 에러 페이지, 디코드 불가 body 등 예상치 못한 응답이 왔을 때.
    case unexpectedResponse(message: String)
}

extension AuthKitError {
    /// 사용자가 단순히 provider 시트를 닫았을 때만 true — 호출부는 보통 실패
    /// 메시지를 띄우지 않고 조용히 넘어간다.
    public var isCancelled: Bool {
        if case .cancelled = self { return true }
        return false
    }
}

extension AuthKitError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .cancelled:
            return "로그인이 취소되었습니다."
        case let .missingPresenter(provider):
            return "\(provider.rawValue) 로그인 UI를 띄울 화면(presenter)이 없습니다."
        case let .unknownProvider(provider):
            return "등록되지 않은 provider 입니다: \(provider.rawValue) (조립 시 providers 배열 확인)"
        case .missingCredential:
            return "인증에 필요한 credential이 없습니다. (Kakao라면 콘솔의 OpenID Connect 활성화 여부 확인)"
        case let .providerFailed(provider, underlying):
            return "\(provider.rawValue) 로그인에 실패했습니다: \(underlying.localizedDescription)"
        case let .backendHTTP(statusCode, message):
            return "인증 백엔드 오류 (HTTP \(statusCode)): \(message)"
        case let .backendNetwork(underlying):
            return "네트워크 오류로 인증에 실패했습니다: \(underlying.localizedDescription)"
        case .sessionNotFound:
            return "로그인 세션이 없습니다."
        case let .unexpectedResponse(message):
            return "예상치 못한 응답입니다: \(message)"
        }
    }
}
