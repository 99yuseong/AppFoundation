//
//  EndpointTask.swift
//  AppFoundation / APIKit
//
//  요청 페이로드의 선언적 분류 — Moya `Task` 의 슬림판. verb 별 메서드 분리 대신
//  "요청이 어떤 형태의 페이로드를 갖는가"를 엔드포인트 선언으로 명시한다.
//  multipart/download 등은 실제 수요가 생길 때 케이스를 추가한다.
//

import Foundation

public enum EndpointTask: Sendable {

    /// 페이로드 없음 (realtime 구독 등).
    case plain

    /// JSON body. EF/RPC 전송의 실제 페이로드.
    case json(any Encodable & Sendable)

    /// URL query 파라미터 (GET 류 — REST 백엔드 확장 대비 선언).
    case query([URLQueryItem])

    /// 바이너리 업로드 (storage 류).
    case upload(data: Data, contentType: String)
}
