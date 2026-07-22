//
//  EndpointTransport.swift
//  AppFoundation / APIKit
//
//  서버 엔드포인트 호출의 전송 방식. 닫힌 enum 이 아니라 String 기반 struct 다
//  (`SocialProvider` 선례) — 새 백엔드가 kit 수정 없이 자체 transport 를 정의할 수 있다.
//  백엔드는 자기가 아는 transport 만 분기하고, 모르는 값은 에러로 드러낸다.
//

public struct EndpointTransport: RawRepresentable, Hashable, Sendable, CustomStringConvertible {

    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue }

    /// 서버 함수 호출 (Supabase: `functions.invoke`). 로직이 서버에 있다.
    public static let edgeFunction = EndpointTransport(rawValue: "edgeFunction")

    /// 프로시저 호출 (Supabase: `client.rpc`).
    public static let rpc = EndpointTransport(rawValue: "rpc")

    /// 테이블 직접 조작. 현재 구현체는 클라이언트에서 Supabase SDK 로 실행한다.
    public static let database = EndpointTransport(rawValue: "database")

    /// 오브젝트 저장소 조작. 현재 구현체는 클라이언트에서 Supabase Storage SDK 로 실행한다.
    public static let storage = EndpointTransport(rawValue: "storage")

    /// 구독 스트림. `APIClient.stream(_:)` 으로만 호출한다.
    public static let realtime = EndpointTransport(rawValue: "realtime")
}
