//
//  APIEnvelope.swift
//  AppFoundation / APIKit
//
//  서버 함수(EF 등) 공통 응답 계약 — 백엔드 중립(자체 서버도 같은 계약을 쓸 수 있다):
//    성공(2xx): { "ok": true,  "data": {...} }
//    실패(4xx~): { "ok": false, "error": { "code", "message" } }
//  성공/실패 envelope 을 별도 타입으로 나눠 각 경로에서 디코딩한다.
//

/// 성공 응답 envelope. `data` 만 꺼내 쓴다.
public struct APIEnvelope<Payload: Decodable>: Decodable {
    public let ok: Bool
    public let data: Payload
}

/// 실패 응답 envelope. `APIError` 매핑의 원료.
public struct APIErrorEnvelope: Decodable {

    public struct ErrorBody: Decodable {
        public let code: String
        public let message: String
    }

    public let ok: Bool
    public let error: ErrorBody
}
