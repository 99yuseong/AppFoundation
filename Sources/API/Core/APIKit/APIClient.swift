//
//  APIClient.swift
//  AppFoundation / APIKit
//
//  서버 호출 진입점 — 앱단에서는 EF/RPC/DB/Storage/Realtime 을 하나의 API 로 간주한다.
//  호출 종류는 엔드포인트 선언(transport·method·task)으로 구분하고, 전송 방식은
//  백엔드 구현체(APIKitSupabase 등)가 정한다.
//
//  verb 별 메서드(get/post…)를 두지 않는다 — 전송 세부가 호출부(Repository)에 새면
//  백엔드 이전 시 호출부가 바뀐다. Moya 와 같은 단일 진입 + 선언 메타데이터 구조.
//

public protocol APIClient: Sendable {

    /// 이름 붙은 서버 엔드포인트를 호출하고 결과를 디코딩한다 (단발 호출).
    func request<Response: Decodable>(
        _ endpoint: some Endpoint
    ) async throws -> Response

    /// 구독형 엔드포인트(`.realtime`)를 구독한다. 구독 설정(async) 후 이벤트 스트림을
    /// 반환하며, 스트림 종료(취소 포함) 시 구독 해지는 endpoint 구현이 책임진다.
    func stream<Event: Decodable & Sendable>(
        _ endpoint: some Endpoint
    ) async throws -> AsyncThrowingStream<Event, Error>
}

/// 응답 본문을 쓰지 않는 엔드포인트의 Response 타입.
public struct EmptyResponse: Decodable, Sendable {
    public init() {}
}
