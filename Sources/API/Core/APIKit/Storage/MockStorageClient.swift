//
//  MockStorageClient.swift
//  AppFoundation / APIKit
//
//  StorageClient 목 — 호출을 기록하고 결정적 값을 돌려준다. kit 에 포함하는 이유는
//  MockAPIClient 와 같다: 사용 앱의 테스트가 픽스처를 재작성하지 않도록.
//

import Foundation

public final class MockStorageClient: StorageClient, @unchecked Sendable {
    // @unchecked 근거: 가변 상태는 전부 lock 아래.

    /// 기록된 업로드 1건.
    public struct Upload: Sendable {
        public let bucketName: String
        public let path: String
        public let contentType: String
        public let data: Data
    }

    /// 기록된 URL 요청 1건.
    public struct URLLookup: Sendable {
        public let bucketName: String
        public let path: String
    }

    /// 기록된 삭제 요청 1건.
    public struct Deletion: Sendable {
        public let bucketName: String
        public let path: String
    }

    private let failure: (any Error)?
    private let lock = NSLock()
    private var _uploads: [Upload] = []
    private var _urlLookups: [URLLookup] = []
    private var _deletions: [Deletion] = []

    /// 기록된 업로드 (순서 보존).
    public var uploads: [Upload] { lock.withLock { _uploads } }

    /// 기록된 URL 요청 (순서 보존).
    public var urlLookups: [URLLookup] { lock.withLock { _urlLookups } }

    /// 기록된 삭제 요청 (순서 보존).
    public var deletions: [Deletion] { lock.withLock { _deletions } }

    /// - Parameter failure: 지정하면 모든 호출이 기록 후 이 에러를 던진다.
    public init(failure: (any Error)? = nil) {
        self.failure = failure
    }

    /// 넘긴 path 를 그대로 서버 확정 경로로 돌려준다.
    @discardableResult
    public func upload(
        _ data: Data,
        to bucket: any StorageBucket.Type,
        path: String,
        contentType: String
    ) async throws -> String {
        lock.withLock {
            _uploads.append(Upload(bucketName: bucket.bucketName, path: path, contentType: contentType, data: data))
        }
        if let failure { throw failure }
        return path
    }

    /// `mock://{bucketName}/{path}` 형태의 결정적 URL 을 돌려준다.
    public func url(
        for bucket: any StorageBucket.Type,
        path: String
    ) async throws -> URL {
        lock.withLock {
            _urlLookups.append(URLLookup(bucketName: bucket.bucketName, path: path))
        }
        if let failure { throw failure }
        guard let url = URL(string: "mock://\(bucket.bucketName)/\(path)") else {
            throw APIError.invalidRequest(message: "MockStorageClient — path 로 URL 을 만들 수 없음: \(path)")
        }
        return url
    }

    /// 호출을 기록만 한다 — 실제로 지우는 오브젝트가 없다(테스트 대역).
    public func delete(
        from bucket: any StorageBucket.Type,
        path: String
    ) async throws {
        lock.withLock {
            _deletions.append(Deletion(bucketName: bucket.bucketName, path: path))
        }
        if let failure { throw failure }
    }
}
