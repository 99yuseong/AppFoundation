//
//  TestEndpoint.swift
//  AppFoundation / APIKitTests
//
//  테스트 공용 엔드포인트 픽스처.
//

import APIKit

struct TestEndpoint: Endpoint {
    let name: String
    let transport: EndpointTransport
    var method: HTTPMethod = .post
    var task: EndpointTask = .plain
}
