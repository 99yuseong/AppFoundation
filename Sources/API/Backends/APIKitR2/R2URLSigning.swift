//
//  R2URLSigning.swift
//  AppFoundation / APIKitR2
//
//  R2 접근 티켓(presigned URL) 발급 계약. R2 에는 세션·RLS 가 없고 인증 수단이
//  S3 키뿐인데 그 키를 앱에 심을 수 없으므로, 서명은 키를 가진 서버(Worker)가
//  대신한다 — 이 계약은 "누가 어떻게 서명해 주는가"를 추상화한다.
//  기본 구현은 WorkerR2Signer(동봉 Worker 템플릿과 짝).
//

import Foundation
import APIKit

/// R2 presigned URL 발급 계약.
public protocol R2URLSigning: Sendable {

    /// `bucketName/path` 오브젝트에 대해 `method` 로 접근 가능한 서명 URL 을 발급한다.
    /// - Parameters:
    ///   - contentType: PUT 서명에 포함할 Content-Type. 서명에 포함되면 실제 전송도
    ///     같은 값을 실어야 한다 (GET 은 nil).
    ///   - expiresIn: 서명 유효 시간(초).
    func signedURL(
        bucketName: String,
        path: String,
        method: HTTPMethod,
        contentType: String?,
        expiresIn: TimeInterval
    ) async throws -> URL
}
