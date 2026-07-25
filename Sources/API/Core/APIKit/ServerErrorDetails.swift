//
//  ServerErrorDetails.swift
//  AppFoundation / APIKit
//
//  실패 응답의 **부가 필드**를 앱까지 전달하는 통로. `code`/`message` 두 문자열로는
//  표현할 수 없는 값(재시도 대상 id, 잔여 수량 등)을 서버가 error 객체에 함께 실어
//  보내는 경우가 있는데, 그 값이 매핑 경계에서 버려지지 않게 한다.
//
//  kit 은 이 값을 **해석하지 않는다** — 어떤 키가 오는지는 앱·서버 계약이므로
//  `mapServerError` 훅이 꺼내 쓴다. 앱 전용 키를 kit 타입의 프로퍼티로 올리지 않는
//  것이 "앱 전용 에러 코드를 APIError 케이스로 승격하지 않는다"와 같은 규칙이다.
//

import Foundation

/// 실패 응답 본문 원본. 백엔드가 채우고 앱이 읽는다.
public struct ServerErrorDetails: Sendable, Equatable {

    /// 실패 응답 본문 원본(`{ok:false, error:{...}}` 전체).
    /// 스키마를 모른 채 보관하기 위해 디코딩하지 않고 Data 로 들고 있는다.
    public let rawBody: Data

    public init(rawBody: Data) {
        self.rawBody = rawBody
    }

    /// error 객체를 앱 타입으로 디코딩한다. 형태가 다르면 `nil`
    /// (부가 필드는 **있을 때만 의미가 있는** 값이라 없는 것이 정상 경로다).
    ///
    /// `{ok, error:{...}}` 의 **error 객체**를 대상으로 디코딩한다 — 앱이 관심 있는
    /// 부가 필드가 그 안에 실려 오기 때문이다(envelope 껍데기는 kit 규약).
    public func decode<Payload: Decodable>(
        _ type: Payload.Type,
        using decoder: JSONDecoder = JSONDecoder()
    ) -> Payload? {
        guard let errorObject else { return nil }
        return try? decoder.decode(type, from: errorObject)
    }

    /// error 객체의 단일 문자열 필드 조회 — id 하나만 필요한 흔한 경우의 지름길.
    ///
    /// 숫자·불리언은 문자열로 바꿔 주지 않는다(조용한 타입 혼동 방지). 그런 값은
    /// ``decode(_:using:)`` 으로 전용 타입에 받는다.
    public func string(forKey key: String) -> String? {
        guard
            let errorObject,
            let object = try? JSONSerialization.jsonObject(with: errorObject) as? [String: Any],
            let value = object[key] as? String
        else {
            return nil
        }
        return value
    }

    /// 본문에서 error 객체만 떼어낸 JSON. envelope 규약 밖이면 본문 전체로 폴백한다
    /// (게이트웨이 등 `{ok,error}` 를 안 쓰는 응답에서도 부가 필드를 읽을 수 있게).
    private var errorObject: Data? {
        guard
            let root = try? JSONSerialization.jsonObject(with: rawBody) as? [String: Any]
        else {
            return nil
        }
        guard let error = root["error"] as? [String: Any] else { return rawBody }
        return try? JSONSerialization.data(withJSONObject: error)
    }
}
