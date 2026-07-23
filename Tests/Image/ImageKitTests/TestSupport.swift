//
//  TestSupport.swift
//  AppFoundation / ImageKitTests
//
//  공용 픽스처: PNG 생성, 바이너리 응답 URLProtocol 스텁(요청 카운터 포함),
//  @Sendable 클로저에서 쓰는 잠금 박스.
//

import UIKit
import Foundation

enum TestImages {

    /// 지정 픽셀 크기의 단색 PNG (scale 1).
    static func pngData(width: Int, height: Int) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: width, height: height),
            format: format
        )
        return renderer.pngData { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }
}

/// 바이너리 body 스텁 (AuthKitTests 의 StubURLProtocol 패턴 — 이미지라 Data 반환 +
/// 재시도/dedup 검증용 요청 카운터를 더했다).
final class StubImageURLProtocol: URLProtocol {

    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (Int, Data))?

    private nonisolated(unsafe) static var _requestCount = 0
    private static let lock = NSLock()

    static var requestCount: Int {
        lock.withLock { _requestCount }
    }

    static func reset() {
        lock.withLock { _requestCount = 0 }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.withLock { Self._requestCount += 1 }

        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }

        do {
            let (statusCode, body) = try handler(request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

/// @Sendable 콜백에서 마지막 값을 담아오는 잠금 박스.
final class LockedBox<Value: Sendable>: @unchecked Sendable {

    private let lock = NSLock()
    private var _value: Value?

    var value: Value? {
        lock.withLock { _value }
    }

    func set(_ newValue: Value) {
        lock.withLock { _value = newValue }
    }
}
