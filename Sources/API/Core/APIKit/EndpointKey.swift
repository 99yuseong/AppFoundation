//
//  EndpointKey.swift
//  AppFoundation / APIKit
//
//  Endpoint existential/generic 값을 테스트 목이나 기록용 컬렉션에서 쓰기 위한 식별자.
//  name + transport 만 키로 삼는다 — method/task 는 선언 메타데이터라 식별에 불필요.
//

public struct EndpointKey: Hashable, Sendable {

    public let name: String
    public let transport: EndpointTransport

    public init(_ endpoint: some Endpoint) {
        self.name = endpoint.name
        self.transport = endpoint.transport
    }

    public init(name: String, transport: EndpointTransport) {
        self.name = name
        self.transport = transport
    }
}
