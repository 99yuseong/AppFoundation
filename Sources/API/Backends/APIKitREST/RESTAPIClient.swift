//
//  RESTAPIClient.swift
//  AppFoundation / APIKitREST
//
//  APIClient 의 URLSession 실구현 — 외부 의존 zero 라 별도 타깃 없이 APIKit 타깃에
//  포함된다 (AuthKitREST 선례). Moya 의 provider 상당: 엔드포인트 선언(name·method·
//  task)을 URLRequest 로 조립해 전송하고, verb 별 메서드는 두지 않는다.
//
//  두 얼굴을 unwrapping 주입으로 흡수한다:
//    - .raw (기본): 응답 본문 전체가 Response — 서드파티/일반 REST
//    - .envelope: `{ok:true,data}` 의 data 만 디코딩 — 자기 서버 계약(opt-in).
//      Supabase EF 에서 자기 서버로 이전할 때 이 모드가 EF 와 같은 계약을 유지한다.
//  실패 본문이 envelope 계약(`{ok:false,error}`)이면 unwrapping 과 무관하게 code 를
//  뽑아 `mapServerError` 훅 → 중립 APIError 순으로 매핑한다 (Supabase 백엔드와 대칭).
//
//  인증 토큰 주입·공통 헤더 가공은 `adapt` 클로저 하나로 처리한다 — Moya plugin
//  체계는 필요가 증명되기 전엔 들이지 않는다. per-endpoint headers 도 같은 이유로
//  없다 (필요 시 정제 프로토콜로 opt-in).
//

import Foundation
import os

public struct RESTAPIClient: APIClient {

    /// 성공 응답 본문의 해석 방식.
    public enum ResponseUnwrapping: Sendable {
        /// 본문 전체를 Response 로 디코딩 (서드파티/일반 REST 기본).
        case raw
        /// `{ok:true, data:{...}}` envelope 의 data 만 디코딩 (자기 서버 계약).
        case envelope
    }

    /// 모든 엔드포인트 path 앞에 붙는 서버 주소. `/api/v1` 같은 공통 prefix 도 여기 소속 —
    /// 엔드포인트는 호스트를 모른다 (백엔드 교체 무변경의 전제, Endpoint 주석 참조).
    private let baseURL: URL

    private let session: URLSession
    private let defaultHeaders: [String: String]

    /// 전송 직전 요청 가공 훅 — 인증 토큰 주입 등. async 라 토큰 갱신도 여기서 가능하다.
    private let adapt: (@Sendable (URLRequest) async throws -> URLRequest)?

    private let unwrapping: ResponseUnwrapping

    /// 서버 에러 → 앱 도메인 에러 훅. nil 반환 시 중립 `APIError` 폴백.
    /// `details` 는 실패 본문이 `{ok:false,error}` 규약일 때 원본이 실린다.
    private let mapServerError: (
        @Sendable (_ code: String, _ message: String, _ details: ServerErrorDetails?) -> (any Error)?
    )?

    private let logger = Logger(subsystem: "AppFoundation", category: "APIKit.REST")

    /// 설정 없는 read-only 용도라 인스턴스 공유가 안전 (SupabaseAPIClient 와 동일).
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    /// 부가 필드까지 받는 훅으로 조립한다.
    public init(
        baseURL: URL,
        session: URLSession = .shared,
        defaultHeaders: [String: String] = [:],
        adapt: (@Sendable (URLRequest) async throws -> URLRequest)? = nil,
        unwrapping: ResponseUnwrapping = .raw,
        mapServerError: (
            @Sendable (_ code: String, _ message: String, _ details: ServerErrorDetails?) -> (any Error)?
        )? = nil
    ) {
        self.baseURL = baseURL
        self.session = session
        self.defaultHeaders = defaultHeaders
        self.adapt = adapt
        self.unwrapping = unwrapping
        self.mapServerError = mapServerError
    }

    /// `(code, message)` 훅만 쓰는 호출부용 팩토리.
    ///
    /// **생성자 오버로드로 두지 않는다** — 클로저 인자 수만 다른 오버로드는 클로저
    /// 리터럴의 타입이 문맥에서 정해지므로 `self.init` 이 자기 자신으로 해소돼
    /// 무한 재귀가 된다(실제로 그렇게 썼다가 컴파일러가 잡았다). 이름을 달리 둔다.
    public static func withSimpleErrorMapping(
        baseURL: URL,
        session: URLSession = .shared,
        defaultHeaders: [String: String] = [:],
        adapt: (@Sendable (URLRequest) async throws -> URLRequest)? = nil,
        unwrapping: ResponseUnwrapping = .raw,
        mapServerError: @escaping @Sendable (_ code: String, _ message: String) -> (any Error)?
    ) -> RESTAPIClient {
        RESTAPIClient(
            baseURL: baseURL,
            session: session,
            defaultHeaders: defaultHeaders,
            adapt: adapt,
            unwrapping: unwrapping,
            mapServerError: { code, message, _ in mapServerError(code, message) }
        )
    }

    // MARK: - APIClient

    public func request<Response: Decodable>(
        _ endpoint: some Endpoint
    ) async throws -> Response {

        logger.debug("→ \(endpoint.name, privacy: .public) [\(endpoint.transport.rawValue, privacy: .public)·\(endpoint.method.rawValue, privacy: .public)] 호출")

        guard endpoint.transport == .http else {
            throw APIError.server(
                code: "unsupported_transport",
                message: "\(endpoint.name) 의 transport(\(endpoint.transport.rawValue))를 RESTAPIClient 가 지원하지 않음"
            )
        }

        do {
            var urlRequest = try makeURLRequest(endpoint)
            if let adapt {
                urlRequest = try await adapt(urlRequest)
            }

            let (data, response) = try await session.data(for: urlRequest)

            guard let http = response as? HTTPURLResponse else {
                throw APIError.server(code: "invalid_response", message: "\(endpoint.name) HTTP 응답이 아님")
            }
            try validate(http, data: data)

            let result: Response = try decode(data)

            logger.info("← \(endpoint.name, privacy: .public) 성공")

            return result

        } catch {
            logger.error("← \(endpoint.name, privacy: .public) 실패: \(String(describing: error), privacy: .public)")
            throw error
        }
    }

    public func stream<Event: Decodable & Sendable>(
        _ endpoint: some Endpoint
    ) async throws -> AsyncThrowingStream<Event, Error> {
        // SSE/WebSocket 은 실제 수요가 생길 때 — v1 은 단발 호출만.
        throw APIError.server(
            code: "unsupported_transport",
            message: "\(endpoint.name) — RESTAPIClient 는 stream(구독)을 지원하지 않음"
        )
    }

    // MARK: - 요청 조립

    private func makeURLRequest(_ endpoint: some Endpoint) throws -> URLRequest {
        var url = baseURL.appending(path: endpoint.name)
        if case .query(let items) = endpoint.task, !items.isEmpty {
            url.append(queryItems: items)
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue

        for (field, value) in defaultHeaders {
            request.setValue(value, forHTTPHeaderField: field)
        }

        switch endpoint.task {
        case .plain, .query:
            break
        case .json(let body):
            request.httpBody = try Self.encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        case .upload(let data, let contentType):
            request.httpBody = data
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }

        return request
    }

    // MARK: - 응답 처리

    /// 비-2xx 를 에러로. 실패 본문이 envelope 계약이면 훅 매핑을 태우고,
    /// 규약 밖 본문은 상태코드 기반 중립 에러로.
    private func validate(_ response: HTTPURLResponse, data: Data) throws {
        guard !(200..<300).contains(response.statusCode) else { return }

        if let envelope = try? Self.decoder.decode(APIErrorEnvelope.self, from: data) {
            throw mapError(
                code: envelope.error.code,
                message: envelope.error.message,
                details: ServerErrorDetails(rawBody: data)
            )
        }

        let message = String(decoding: data, as: UTF8.self)
        if response.statusCode == 401 {
            throw APIError.unauthorized(message: message)
        }
        throw APIError.server(code: "http_\(response.statusCode)", message: message)
    }

    private func decode<Response: Decodable>(_ data: Data) throws -> Response {
        // 본문 없는 2xx(204 등) + EmptyResponse 선언은 디코딩 없이 통과시킨다.
        if data.isEmpty, let empty = EmptyResponse() as? Response {
            return empty
        }

        switch unwrapping {
        case .raw:
            return try Self.decoder.decode(Response.self, from: data)
        case .envelope:
            return try Self.decoder.decode(APIEnvelope<Response>.self, from: data).data
        }
    }

    /// 훅 우선 → 중립 `APIError` 폴백 (SupabaseAPIClient.mapError 와 동일 계약).
    /// (internal — 단위 테스트 대상)
    func mapError(
        code: String,
        message: String,
        details: ServerErrorDetails? = nil
    ) -> any Error {
        if let custom = mapServerError?(code, message, details) {
            return custom
        }
        return APIError(code: code, message: message)
    }
}
