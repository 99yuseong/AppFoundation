//
//  SupabaseStorageClient.swift
//  AppFoundation / APIKitSupabase
//
//  StorageClient 의 Supabase Storage 실구현. SupabaseAPIClient 와 대칭 —
//  APIClient 가 endpoint 를 실행하듯 StorageClient 는 오브젝트를 실행한다.
//  세션 JWT 는 공유 SupabaseClient 가 자동으로 실어 storage RLS 를 통과한다.
//
//  에러는 SDK 의 StorageError 를 그대로 던진다 — APIClient(.storage) 경로를 타면
//  invokeStorage 가 mapServerError 훅으로 매핑한다 (직접 쓰는 경우 호출부 소관).
//
//  이름 충돌 주의: supabase-swift 도 SupabaseStorageClient(client.storage 의 타입)를
//  정의한다. 앱은 보통 이 타입을 직접 쓰지 않지만(주입 생략 시 기본 생성), 양쪽을
//  import 한 파일에서 이름을 써야 하면 `APIKitSupabase.SupabaseStorageClient` 로
//  한정한다.
//

import Foundation
import APIKit
import Supabase

public struct SupabaseStorageClient: StorageClient {

    /// 앱 전역 유일 SupabaseClient (SupabaseAPIClient 와 같은 인스턴스).
    let client: SupabaseClient

    /// 서명 URL 재사용 캐시. 캐시 수명 = 이 인스턴스 수명이므로 요청마다 만들지
    /// 말고 조립에서 하나를 유지한다 (SupabaseAPIClient 가 이 규칙대로 소유한다).
    private let cache: SignedURLCache

    public init(client: SupabaseClient, cache: SignedURLCache = SignedURLCache()) {
        self.client = client
        self.cache = cache
    }

    @discardableResult
    public func upload(
        _ data: Data,
        to bucket: any StorageBucket.Type,
        path: String,
        contentType: String
    ) async throws -> String {
        try await client.storage
            .from(bucket.bucketName)
            .upload(path, data: data, options: FileOptions(contentType: contentType, upsert: true))
            .path
    }

    public func url(
        for bucket: any StorageBucket.Type,
        path: String
    ) async throws -> URL {
        if bucket.isPublic {
            return try client.storage.from(bucket.bucketName).getPublicURL(path: path)
        }
        if let cached = cache.url(forBucket: bucket.bucketName, path: path) {
            return cached
        }
        let url = try await client.storage
            .from(bucket.bucketName)
            .createSignedURL(path: path, expiresIn: Int(bucket.signedURLExpiry))
        cache.store(url, forBucket: bucket.bucketName, path: path, expiresIn: bucket.signedURLExpiry)
        return url
    }
}
