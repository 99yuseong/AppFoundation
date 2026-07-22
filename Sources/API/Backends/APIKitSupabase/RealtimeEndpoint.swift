//
//  RealtimeEndpoint.swift
//  AppFoundation / APIKitSupabase
//
//  Realtime endpoint — Database/Storage 와 대칭 구조의 구독형. 엔드포인트가 자기
//  채널/필터를 알고, executeStream 안에서 Supabase Realtime SDK 로 직접 구독한다.
//  채널 구성(postgresChange/broadcast/presence)과 해지(스트림 종료·취소 시
//  unsubscribe — AsyncThrowingStream 의 onTermination 활용)는 엔드포인트 구현의
//  책임이다. APIClient 는 전송 방식(.realtime)만 보고 stream(_:) 에서 이 메서드로 넘긴다.
//

import APIKit
import Supabase

public protocol RealtimeEndpoint: Endpoint {
    func executeStream<Event: Decodable & Sendable>(
        context: RealtimeContext,
        event: Event.Type
    ) async throws -> AsyncThrowingStream<Event, Error>
}

public struct RealtimeContext: Sendable {

    public let client: SupabaseClient

    public init(client: SupabaseClient) {
        self.client = client
    }
}
