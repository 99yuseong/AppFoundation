//
//  R2StorageClient.swift
//  AppFoundation / APIKitR2
//
//  StorageClient 의 Cloudflare R2 실구현 — 외부 의존 zero 라 별도 타깃 없이 APIKit
//  타깃에 포함된다 (APIKitREST 선례). 업로드·다운로드 모두 티켓제:
//  signer(Worker)에게 presigned URL 을 받아 URLSession 으로 직접 PUT/GET 한다.
//  앱에는 S3 키가 없다.
//
//  public 버킷의 고정 URL 은 커스텀 도메인에서 파생된다 — 저장소 사정이므로 중립
//  계약(StorageBucket)에 올리지 않고 생성자 설정(publicBaseURLs)으로 격리한다.
//

import Foundation

public struct R2StorageClient: StorageClient {

    /// presigned URL 발급자. 기본 구현은 WorkerR2Signer.
    private let signer: any R2URLSigning

    /// public 버킷의 고정 URL 베이스 — 버킷명 → 커스텀 도메인 (예: "covers" →
    /// https://cdn.example.com). public 버킷을 쓰면 반드시 등록한다.
    private let publicBaseURLs: [String: URL]

    private let session: URLSession

    /// 서명 URL 재사용 캐시. 캐시 수명 = 이 인스턴스 수명이므로 조립에서 하나를 유지한다.
    private let cache: SignedURLCache

    /// 업로드 티켓의 서명 유효 시간. 발급 직후 1회 쓰고 버리므로 읽기 정책
    /// (bucket.signedURLExpiry)과 무관하게 짧다.
    private static let uploadSignExpiry: TimeInterval = 300

    public init(
        signer: any R2URLSigning,
        publicBaseURLs: [String: URL] = [:],
        session: URLSession = .shared,
        cache: SignedURLCache = SignedURLCache()
    ) {
        self.signer = signer
        self.publicBaseURLs = publicBaseURLs
        self.session = session
        self.cache = cache
    }

    // MARK: - StorageClient

    @discardableResult
    public func upload(
        _ data: Data,
        to bucket: any StorageBucket.Type,
        path: String,
        contentType: String
    ) async throws -> String {

        let signed = try await signer.signedURL(
            bucketName: bucket.bucketName,
            path: path,
            method: .put,
            contentType: contentType,
            expiresIn: Self.uploadSignExpiry
        )

        var request = URLRequest(url: signed)
        request.httpMethod = HTTPMethod.put.rawValue
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")   // 서명에 포함된 값과 일치해야 한다

        let (_, response) = try await session.upload(for: request, from: data)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError.server(
                code: "r2_upload_failed_\(status)",
                message: "R2 업로드 실패 \(status) — \(bucket.bucketName)/\(path)"
            )
        }

        // S3 PUT 은 경로를 정규화하지 않는다 — 요청 path 가 그대로 정본.
        return path
    }

    public func url(
        for bucket: any StorageBucket.Type,
        path: String
    ) async throws -> URL {

        if bucket.isPublic {
            guard let base = publicBaseURLs[bucket.bucketName] else {
                throw APIError.server(
                    code: "missing_public_base_url",
                    message: "public 버킷 \(bucket.bucketName) 의 publicBaseURLs 미등록 — R2StorageClient 조립 확인"
                )
            }
            return base.appendingPathComponent(path)
        }

        if let cached = cache.url(forBucket: bucket.bucketName, path: path) {
            return cached
        }
        let url = try await signer.signedURL(
            bucketName: bucket.bucketName,
            path: path,
            method: .get,
            contentType: nil,
            expiresIn: bucket.signedURLExpiry
        )
        cache.store(url, forBucket: bucket.bucketName, path: path, expiresIn: bucket.signedURLExpiry)
        return url
    }

    /// 티켓제 삭제 — Worker 에 DELETE presign 을 받아 직접 DELETE 한다.
    /// S3 DeleteObject 는 없는 키에도 204 를 돌려주므로 계약의 idempotent 요건을 충족한다.
    public func delete(
        from bucket: any StorageBucket.Type,
        path: String
    ) async throws {

        let signed = try await signer.signedURL(
            bucketName: bucket.bucketName,
            path: path,
            method: .delete,
            contentType: nil,
            expiresIn: Self.uploadSignExpiry
        )

        var request = URLRequest(url: signed)
        request.httpMethod = HTTPMethod.delete.rawValue

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) || http.statusCode == 404 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError.server(
                code: "r2_delete_failed_\(status)",
                message: "R2 삭제 실패 \(status) — \(bucket.bucketName)/\(path)"
            )
        }
    }
}
