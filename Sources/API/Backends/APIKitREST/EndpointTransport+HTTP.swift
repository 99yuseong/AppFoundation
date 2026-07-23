//
//  EndpointTransport+HTTP.swift
//  AppFoundation / APIKitREST
//
//  일반 HTTP(REST) 전송. Supabase transport 들과 달리 SDK 게이트웨이 없이
//  `RESTAPIClient` 가 URLSession 으로 직접 전송한다 — 엔드포인트가 선언한
//  `method` 가 실제 요청 verb 로, `name` 이 baseURL 뒤의 path 로 쓰인다.
//

extension EndpointTransport {

    /// 일반 HTTP 호출 (`RESTAPIClient` 실행). `Endpoint.name` = URL path,
    /// `Endpoint.method` = 전송 verb — Supabase 백엔드에선 선언용이던 method 가
    /// 여기서 처음 전송에 쓰인다.
    public static let http = EndpointTransport(rawValue: "http")
}
