//
//  SupabaseAPIClient.swift
//  AppFoundation / APIKitSupabase
//
//  APIClient 의 Supabase 실구현 = SupabaseClient 래퍼. 앱에서 supabase-swift 를
//  서버 호출 목적으로 import 하는 곳은 이 타겟뿐이어야 한다.
//
//  엔드포인트 선언(transport)을 보고 실행 경로를 분기한다:
//    - edgeFunction: functions.invoke (게이트웨이가 Authorization: Bearer 를 요구 —
//      SDK 가 anon key/세션 토큰을 자동 첨부. 직접 URLSession 호출 시 401)
//    - rpc: client.rpc (클라 직접 노출 RPC. RLS 로 본인 검증)
//    - database/storage: 엔드포인트가 context 로 SDK 를 직접 실행 (EF 호출 수 제한을
//      피하는 클라 조합 경로 — 서버 확장 시 이 로직이 서버로 이동한다)
//    - realtime: stream(_:) 전용
//  성공 envelope 해체와 실패 본문의 에러 매핑을 여기서 처리해, Repository 구현체는
//  도메인 에러만 다룬다. 앱 전용 에러 코드는 `mapServerError` 훅으로 앱이 매핑한다.
//

import Foundation
import os
import APIKit
import Supabase

public struct SupabaseAPIClient: APIClient {

    /// 이 래퍼가 감싸는 SupabaseClient. **앱 전역 유일 인스턴스**를 주입해야 하며,
    /// AuthKitSupabase 의 `SupabaseAuthBackend` 와 같은 인스턴스여야 로그인 세션이
    /// 서버 호출의 Bearer 토큰에 그대로 실린다 (Composition Root 가 이 값을 넘긴다).
    let client: SupabaseClient

    /// 본인 행 특정용 서비스 유저 id 제공자. DB 직접 조작은 RLS 와 명시적 id 필터를 함께 쓴다.
    private let userIDProvider: any CurrentUserIDProviding

    /// 서버 에러 (code, message) → 앱 도메인 에러 훅. nil 반환 시 중립 `APIError` 폴백.
    private let mapServerError: (@Sendable (_ code: String, _ message: String) -> (any Error)?)?

    private let logger = Logger(subsystem: "AppFoundation", category: "APIKit.Supabase")

    /// RPC 응답 디코딩용 공유 디코더 (설정 없는 read-only 용도라 인스턴스 공유가 안전).
    private static let decoder = JSONDecoder()

    public init(
        client: SupabaseClient,
        userIDProvider: (any CurrentUserIDProviding)? = nil,
        mapServerError: (@Sendable (_ code: String, _ message: String) -> (any Error)?)? = nil
    ) {
        self.client = client
        self.userIDProvider = userIDProvider ?? SupabaseSessionUserIDProvider(client: client)
        self.mapServerError = mapServerError
    }

    // MARK: - APIClient

    public func request<Response: Decodable>(
        _ endpoint: some Endpoint
    ) async throws -> Response {

        logger.debug("→ \(endpoint.name, privacy: .public) [\(endpoint.transport.rawValue, privacy: .public)·\(endpoint.method.rawValue, privacy: .public)] 호출")

        do {
            let response: Response

            switch endpoint.transport {
            case .edgeFunction:
                response = try await invokeEdgeFunction(endpoint.name, task: endpoint.task)
            case .rpc:
                response = try await invokeRPC(endpoint.name, task: endpoint.task)
            case .database:
                response = try await invokeDatabase(endpoint, response: Response.self)
            case .storage:
                response = try await invokeStorage(endpoint, response: Response.self)
            case .realtime:
                throw APIError.server(
                    code: "invalid_entry_point",
                    message: "\(endpoint.name) 은 realtime endpoint — stream(_:) 으로 호출"
                )
            default:
                throw APIError.server(
                    code: "unsupported_transport",
                    message: "\(endpoint.name) 의 transport(\(endpoint.transport.rawValue))를 SupabaseAPIClient 가 지원하지 않음"
                )
            }

            logger.info("← \(endpoint.name, privacy: .public) 성공")

            return response

        } catch {
            logger.error("← \(endpoint.name, privacy: .public) 실패: \(String(describing: error), privacy: .public)")
            throw error
        }
    }

    public func stream<Event: Decodable & Sendable>(
        _ endpoint: some Endpoint
    ) async throws -> AsyncThrowingStream<Event, Error> {

        logger.debug("⇢ \(endpoint.name, privacy: .public) [\(endpoint.transport.rawValue, privacy: .public)·\(endpoint.method.rawValue, privacy: .public)] 구독")

        guard endpoint.transport == .realtime else {
            throw APIError.server(
                code: "invalid_entry_point",
                message: "\(endpoint.name) 은 stream 대상이 아님 — request(_:) 로 호출"
            )
        }
        guard let realtimeEndpoint = endpoint as? any RealtimeEndpoint else {
            throw APIError.server(
                code: "invalid_realtime_endpoint",
                message: "\(endpoint.name) realtime endpoint 타입 불일치"
            )
        }

        let context = RealtimeContext(client: client)
        return try await realtimeEndpoint.executeStream(context: context, event: Event.self)
    }

    // MARK: - 전송 방식별 구현

    /// Edge Function 호출. 성공 envelope 의 data 를 반환, 실패는 에러 매핑.
    private func invokeEdgeFunction<Response: Decodable>(
        _ name: String,
        task: EndpointTask
    ) async throws -> Response {

        guard case .json(let body) = task else {
            throw APIError.server(code: "unsupported_task", message: "\(name) EF 는 .json task 가 필요")
        }

        do {
            let envelope: APIEnvelope<Response> = try await client.functions.invoke(
                name,
                options: FunctionInvokeOptions(body: body)
            )

            return envelope.data

        } catch let error as FunctionsError {
            if let mapped = mapped(error) {
                logger.warning("\(name, privacy: .public) EF 에러 매핑: \(String(describing: mapped), privacy: .public)")
                throw mapped
            }
            throw error
        }
    }

    /// RPC 호출. 파라미터는 `.json` 페이로드를 그대로 넘기고 결과를 디코딩한다.
    /// (RPC 응답은 EF 의 {ok,data} envelope 을 쓰지 않으므로 값 자체를 디코딩)
    ///
    /// RPC 가 RAISE 로 던지는 실패는 PostgrestError 로 오므로 에러 매핑을 태운다 —
    /// EF 의 envelope 매핑과 대칭.
    private func invokeRPC<Response: Decodable>(
        _ name: String,
        task: EndpointTask
    ) async throws -> Response {

        guard case .json(let params) = task else {
            throw APIError.server(code: "unsupported_task", message: "\(name) RPC 는 .json task 가 필요")
        }

        let data: Data

        do {
            data = try await client
                .rpc(name, params: params)
                .execute()
                .data

        } catch let error as PostgrestError {
            let mapped = mapped(error)
            logger.warning("\(name, privacy: .public) RPC 에러 매핑: \(String(describing: mapped), privacy: .public)")
            throw mapped
        }

        return try RPCResponseDecoding.decode(data, name: name, using: Self.decoder)
    }

    /// Database endpoint 를 endpoint 가 직접 실행하는 경로.
    private func invokeDatabase<Response: Decodable>(
        _ endpoint: some Endpoint,
        response: Response.Type
    ) async throws -> Response {
        guard let databaseEndpoint = endpoint as? any DatabaseEndpoint else {
            throw APIError.server(code: "invalid_database_endpoint", message: "\(endpoint.name) database endpoint 타입 불일치")
        }

        let context = DatabaseContext(client: client, userIDProvider: userIDProvider)
        return try await databaseEndpoint.executeDatabase(context: context, response: Response.self)
    }

    /// Storage endpoint 를 endpoint 가 직접 실행하는 경로(업로드). StorageError 는
    /// 에러 매핑을 태운다 — Database/EF 매핑과 대칭.
    private func invokeStorage<Response: Decodable>(
        _ endpoint: some Endpoint,
        response: Response.Type
    ) async throws -> Response {
        guard let storageEndpoint = endpoint as? any StorageEndpoint else {
            throw APIError.server(code: "invalid_storage_endpoint", message: "\(endpoint.name) storage endpoint 타입 불일치")
        }

        let context = StorageContext(client: client)
        do {
            return try await storageEndpoint.executeStorage(context: context, response: Response.self)
        } catch let error as StorageError {
            let mapped = mapError(code: error.statusCode ?? "storage_request_failed", message: error.message)
            logger.warning("\(endpoint.name, privacy: .public) Storage 에러 매핑: \(String(describing: mapped), privacy: .public)")
            throw mapped
        }
    }

    // MARK: - 에러 매핑

    /// FunctionsError 의 실패 본문(`{ok:false,error}`)을 도메인/중립 에러로. 규약 밖이면 nil
    /// (게이트웨이 등 — 호출부가 원본 에러를 그대로 던지도록).
    private func mapped(_ error: FunctionsError) -> (any Error)? {
        guard case .httpError(_, let data) = error else { return nil }
        guard let envelope = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data) else { return nil }
        return mapError(code: envelope.error.code, message: envelope.error.message)
    }

    /// PostgrestError(RPC RAISE)를 도메인/중립 에러로. SQLSTATE 를 code 로 우선 전달하고,
    /// code 가 없으면 message 기반 폴백(서버 공통 에러표 계약 — 예: RAISE 메시지에 의미명).
    private func mapped(_ error: PostgrestError) -> any Error {
        mapError(code: error.code ?? error.message, message: error.message)
    }

    /// 훅 우선 → 중립 `APIError` 폴백. 앱은 훅으로 자기 도메인 에러(제재/기기이전 등)를
    /// 만들어 Repository 가 도메인 에러만 다루게 한다. (internal — 단위 테스트 대상)
    func mapError(code: String, message: String) -> any Error {
        if let custom = mapServerError?(code, message) {
            return custom
        }
        return APIError(code: code, message: message)
    }
}
