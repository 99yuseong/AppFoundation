//
//  WorkerR2Signer.swift
//  AppFoundation / APIKitR2
//
//  R2URLSigning 의 기본 구현 — 동봉된 Cloudflare Worker 템플릿
//  (cloudflare/workers/storage-sign)에 서명을 위임한다. Worker 가 Supabase JWT 를
//  검증하고 본인 폴더(path 접두 = 토큰 sub) 검사를 통과시킨 뒤 SigV4 로 서명한다.
//
//  ── 와이어 계약 (Worker 템플릿과 같은 태그로 버전되는 공개 계약) ──
//  요청  POST {workerURL}  Authorization: Bearer {supabase access token}
//        {"items":[{"bucket","path","method","contentType"?,"expiresIn"}]}
//  응답  {"urls":[{"url","expiresAt"}]}   — items 와 같은 순서, all-or-nothing
//  실패  {"error":{"code","message"}}     — APIErrorEnvelope 계약과 동일
//
//  배열인 이유: 목록 화면의 배치 서명을 Worker 재배포 없이 클라 추가만으로 열어두기
//  위해서다. 현재 Swift API 는 단건만 노출하고 1원소 배열로 감싼다.
//

import Foundation

public struct WorkerR2Signer: R2URLSigning {

    public typealias TokenProvider = @Sendable () async throws -> String

    /// 배포된 storage-sign Worker 주소 (예: https://doran-storage-sign.{계정}.workers.dev).
    private let workerURL: URL

    /// Worker 가 검증할 Supabase access token 제공자. 조립에서 세션 소유자
    /// (SupabaseClient 등)에 연결한다 — 이 타입은 Supabase 를 모른다.
    private let tokenProvider: TokenProvider

    private let session: URLSession

    public init(
        workerURL: URL,
        tokenProvider: @escaping TokenProvider,
        session: URLSession = .shared
    ) {
        self.workerURL = workerURL
        self.tokenProvider = tokenProvider
        self.session = session
    }

    // MARK: - 와이어 DTO

    private struct SignRequest: Encodable {
        struct Item: Encodable {
            let bucket: String
            let path: String
            let method: String
            let contentType: String?
            let expiresIn: Int
        }
        let items: [Item]
    }

    private struct SignResponse: Decodable {
        struct Entry: Decodable {
            let url: String
        }
        let urls: [Entry]
    }

    // MARK: - R2URLSigning

    public func signedURL(
        bucketName: String,
        path: String,
        method: HTTPMethod,
        contentType: String?,
        expiresIn: TimeInterval
    ) async throws -> URL {

        var request = URLRequest(url: workerURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(try await tokenProvider())", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(SignRequest(items: [
            .init(
                bucket: bucketName,
                path: path,
                method: method.rawValue,
                contentType: contentType,
                expiresIn: Int(expiresIn)
            ),
        ]))

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.server(code: "invalid_sign_response", message: "storage-sign 응답이 HTTP 가 아님")
        }
        guard (200..<300).contains(http.statusCode) else {
            // Worker 실패 본문은 {ok:false,error} envelope 계약 — 규약 밖이면 상태코드 기반 중립 에러.
            if let mapped = APIError(envelopeData: data) { throw mapped }
            throw APIError.server(
                code: "sign_request_failed_\(http.statusCode)",
                message: "storage-sign \(http.statusCode) — \(bucketName)/\(path)"
            )
        }

        guard
            let decoded = try? JSONDecoder().decode(SignResponse.self, from: data),
            let first = decoded.urls.first,
            let url = URL(string: first.url)
        else {
            throw APIError.server(code: "invalid_sign_response", message: "storage-sign 응답 형식 불일치")
        }
        return url
    }
}
