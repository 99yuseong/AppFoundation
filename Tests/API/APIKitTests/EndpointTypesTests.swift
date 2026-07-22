//
//  EndpointTypesTests.swift
//  AppFoundation / APIKitTests
//

import Foundation
import Testing
@testable import APIKit

@Suite("Endpoint 메타데이터")
struct EndpointTypesTests {

    @Test("EndpointKey — name+transport 동등성, method/task 는 식별에 무관")
    func endpointKey() {
        let a = TestEndpoint(name: "session_init", transport: .rpc, method: .post, task: .plain)
        let b = TestEndpoint(name: "session_init", transport: .rpc, method: .get, task: .query([]))
        #expect(EndpointKey(a) == EndpointKey(b))
        #expect(EndpointKey(a) == EndpointKey(name: "session_init", transport: .rpc))
        #expect(EndpointKey(a) != EndpointKey(name: "session_init", transport: .edgeFunction))
    }

    @Test("개방형 transport/method — kit 수정 없이 자체 값 정의")
    func openValues() {
        let graphQL = EndpointTransport(rawValue: "graphQL")
        #expect(graphQL != .edgeFunction)
        #expect(graphQL.rawValue == "graphQL")

        let propfind = HTTPMethod(rawValue: "PROPFIND")
        #expect(propfind.rawValue == "PROPFIND")
        #expect(HTTPMethod.get.rawValue == "GET")
        #expect(HTTPMethod.patch.rawValue == "PATCH")
    }
}
