//
//  ImageLoaderTests.swift
//  AppFoundation / ImageKitTests
//
//  파이프라인 순서(메모리→디스크→네트워크)·in-flight dedup·forceRefresh·재시도·
//  진행률을 검증한다. URLProtocol 핸들러·카운터가 전역 상태라 suite 를 직렬화한다.
//  디스크 캐시는 테스트마다 고유 디렉터리를 쓴다.
//

import UIKit
import Foundation
import Testing
import ImageKit
import CoreKit

@Suite("ImageLoader", .serialized)
struct ImageLoaderTests {

    private static let url = URL(string: "https://example.com/images/a.png")!

    private static func uniqueDiskName() -> String {
        "ImageLoaderTests-\(UUID().uuidString)"
    }

    private static func makeLoader(diskName: String) -> ImageLoader {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubImageURLProtocol.self]
        return ImageLoader(
            session: URLSession(configuration: config),
            memoryCache: MemoryCache<UIImage>(),
            diskCache: DiskCache(name: diskName, byteLimit: 0)
        )
    }

    @Test("출처 — 첫 로드 network, 재요청 memory, 새 로더(같은 디스크)는 disk")
    func pipelineSources() async throws {
        StubImageURLProtocol.reset()
        let png = TestImages.pngData(width: 40, height: 40)
        StubImageURLProtocol.handler = { _ in (200, png) }

        let diskName = Self.uniqueDiskName()
        let loader = Self.makeLoader(diskName: diskName)

        let first = try await loader.image(for: Self.url)
        #expect(first.source == .network)

        let second = try await loader.image(for: Self.url)
        #expect(second.source == .memory)
        #expect(StubImageURLProtocol.requestCount == 1)

        // 메모리는 새것, 디스크는 공유 → disk 히트.
        let freshLoader = Self.makeLoader(diskName: diskName)
        let third = try await freshLoader.image(for: Self.url)
        #expect(third.source == .disk)
        #expect(StubImageURLProtocol.requestCount == 1)

        await loader.clearCache()
    }

    @Test("in-flight dedup — 같은 URL 동시 요청은 다운로드 1회를 공유한다")
    func inFlightDeduplication() async throws {
        StubImageURLProtocol.reset()
        let png = TestImages.pngData(width: 40, height: 40)
        StubImageURLProtocol.handler = { _ in
            Thread.sleep(forTimeInterval: 0.05)   // 동시 요청이 실제로 겹치게
            return (200, png)
        }

        let loader = Self.makeLoader(diskName: Self.uniqueDiskName())

        try await withThrowingTaskGroup(of: ImageLoadResult.self) { group in
            for _ in 0..<5 {
                group.addTask { try await loader.image(for: Self.url) }
            }
            for try await _ in group {}
        }

        #expect(StubImageURLProtocol.requestCount == 1)

        await loader.clearCache()
    }

    @Test("forceRefresh — 캐시를 건너뛰고 다시 받는다")
    func forceRefresh() async throws {
        StubImageURLProtocol.reset()
        let png = TestImages.pngData(width: 40, height: 40)
        StubImageURLProtocol.handler = { _ in (200, png) }

        let loader = Self.makeLoader(diskName: Self.uniqueDiskName())

        _ = try await loader.image(for: Self.url)

        let refreshed = try await loader.image(
            for: Self.url,
            options: ImageLoadOptions(forceRefresh: true)
        )
        #expect(refreshed.source == .network)
        #expect(StubImageURLProtocol.requestCount == 2)

        await loader.clearCache()
    }

    @Test("재시도 — maxCount 안에서 성공하면 결과를 반환한다")
    func retrySucceeds() async throws {
        StubImageURLProtocol.reset()
        let png = TestImages.pngData(width: 40, height: 40)
        StubImageURLProtocol.handler = { _ in
            // 1·2번째 시도는 실패, 3번째 성공.
            if StubImageURLProtocol.requestCount < 3 {
                throw URLError(.networkConnectionLost)
            }
            return (200, png)
        }

        let loader = Self.makeLoader(diskName: Self.uniqueDiskName())

        let result = try await loader.image(
            for: Self.url,
            options: ImageLoadOptions(retry: RetryStrategy(maxCount: 2, interval: .milliseconds(10)))
        )
        #expect(result.source == .network)
        #expect(StubImageURLProtocol.requestCount == 3)

        await loader.clearCache()
    }

    @Test("재시도 없음 — 실패가 그대로 throw 된다")
    func noRetryThrows() async throws {
        StubImageURLProtocol.reset()
        StubImageURLProtocol.handler = { _ in (500, Data()) }

        let loader = Self.makeLoader(diskName: Self.uniqueDiskName())

        await #expect(throws: ImageKitError.httpStatus(500)) {
            _ = try await loader.image(for: Self.url)
        }
        #expect(StubImageURLProtocol.requestCount == 1)
    }

    @Test("maxPixelSize — 다운샘플 결과가 반환되고 크기별로 캐시된다")
    func downsampledLoad() async throws {
        StubImageURLProtocol.reset()
        let png = TestImages.pngData(width: 40, height: 40)
        StubImageURLProtocol.handler = { _ in (200, png) }

        let loader = Self.makeLoader(diskName: Self.uniqueDiskName())
        let options = ImageLoadOptions(maxPixelSize: 20)

        let first = try await loader.image(for: Self.url, options: options)
        #expect(first.image.cgImage?.width == 20)
        #expect(first.source == .network)

        // 같은 크기 재요청은 메모리, 다른 크기는 디스크 원본에서 재다운샘플.
        let sameSize = try await loader.image(for: Self.url, options: options)
        #expect(sameSize.source == .memory)
        let original = try await loader.image(for: Self.url)
        #expect(original.source == .disk)
        #expect(original.image.cgImage?.width == 40)
        #expect(StubImageURLProtocol.requestCount == 1)

        await loader.clearCache()
    }

    @Test("진행률 — 완료 시 received 가 전체 크기와 일치한다")
    func progressReporting() async throws {
        StubImageURLProtocol.reset()
        let png = TestImages.pngData(width: 40, height: 40)
        StubImageURLProtocol.handler = { _ in (200, png) }

        let loader = Self.makeLoader(diskName: Self.uniqueDiskName())
        let lastProgress = LockedBox<Int64>()

        _ = try await loader.image(for: Self.url) { received, _ in
            lastProgress.set(received)
        }

        #expect(lastProgress.value == Int64(png.count))

        await loader.clearCache()
    }

    @Test("디스크 손상 항목 — 정리하고 네트워크로 폴백한다")
    func corruptDiskEntryFallsBack() async throws {
        StubImageURLProtocol.reset()
        let png = TestImages.pngData(width: 40, height: 40)
        StubImageURLProtocol.handler = { _ in (200, png) }

        let diskName = Self.uniqueDiskName()
        // 디코드 불가능한 데이터를 같은 키에 심어둔다.
        let disk = DiskCache(name: diskName, byteLimit: 0)
        await disk.store(Data([0xFF, 0x00]), for: Self.url.absoluteString)

        let loader = Self.makeLoader(diskName: diskName)
        let result = try await loader.image(for: Self.url)

        #expect(result.source == .network)
        #expect(StubImageURLProtocol.requestCount == 1)

        await loader.clearCache()
    }
}
