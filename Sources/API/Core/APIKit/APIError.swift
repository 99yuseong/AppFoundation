//
//  APIError.swift
//  AppFoundation / APIKit
//
//  서버가 거절한 이유를 앱이 분기 가능한 형태로 표현하는 중립 에러. 서버 응답 형식
//  (에러 code 문자열, `{ok:false,error}` envelope)의 매핑까지 이 파일에 갇힌다.
//
//  앱 전용 코드(제재/기기 이전 등)는 여기 케이스로 승격하지 않는다 — 백엔드 구현체의
//  `mapServerError` 훅으로 앱이 자기 도메인 에러에 매핑한다. kit 은 어느 앱에나
//  공통인 분류만 케이스로 둔다.
//

import Foundation

/// 서버가 돌려준 중립 에러.
public enum APIError: Error, Equatable {

    /// 요청 형식 오류. 클라 버그 신호.
    case invalidRequest(message: String)

    /// 인증 실패(토큰 누락/무효).
    case unauthorized(message: String)

    /// 위 케이스로 승격되지 않은 나머지 서버 에러.
    case server(code: String, message: String)
}

extension APIError {

    /// 에러 code 문자열 매핑. 공통 코드만 케이스로 승격하고 나머지는 `server` 로 통과시킨다.
    public init(code: String, message: String) {
        switch code {
        case "invalid_request": self = .invalidRequest(message: message)
        case "unauthorized":    self = .unauthorized(message: message)
        default:                self = .server(code: code, message: message)
        }
    }

    /// 실패 응답 본문(`{ok:false, error:{...}}`)에서 매핑. envelope 형식이 아니면 nil
    /// (게이트웨이 등 규약 밖 에러 — 호출부가 원본 에러를 그대로 던지도록).
    public init?(envelopeData: Data) {
        guard let envelope = try? JSONDecoder().decode(APIErrorEnvelope.self, from: envelopeData) else {
            return nil
        }
        self.init(code: envelope.error.code, message: envelope.error.message)
    }
}
