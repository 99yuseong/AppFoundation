//
//  ImageLoader.swift
//  AppFoundation / ImageKit
//
//  원격 이미지 로드 파이프라인:
//    메모리(URL+크기 → 다운샘플된 UIImage) → 디스크(URL → 원본 인코딩 Data) → 네트워크
//  디스크에 원본을 두는 게 핵심이다 — 같은 원본을 다른 크기로 쓸 때 재다운로드 없이
//  재다운샘플만 한다. APIKit 을 경유하지 않고 URLSession 직결 — 이미지 fetch 는
//  바이트 파이프라인이라 request<Decodable> 의 JSON/envelope 의미론과 맞지 않는다.
//
//  같은 URL 의 동시 요청은 다운로드 Task 하나를 공유하고(dedup), 진행률은 대기자
//  전원에게 멀티캐스트한다. 대기자 취소는 공유 다운로드를 멈추지 않는다 — 받은
//  데이터는 캐시에 남아 다음 요청이 즉시 히트한다.
//
//  디코드·다운샘플은 @concurrent 경로에서 실행한다 — 로더 actor 를 잡지 않아
//  동시 로드가 디코드에 직렬화되지 않는다.
//

import UIKit
import CoreKit

/// 로드 결과 — 이미지와 출처. UI 컴포넌트는 출처로 페이드 적용 여부를 정한다
/// (메모리 히트는 즉시 표시, 디스크/네트워크만 페이드 — 깜빡임 방지).
public struct ImageLoadResult: Sendable {

    public enum Source: Sendable, Equatable {
        case memory, disk, network
    }

    public let image: UIImage
    public let source: Source

    public init(image: UIImage, source: Source) {
        self.image = image
        self.source = source
    }
}

public enum ImageKitError: Error, Equatable {
    /// 비-2xx 응답.
    case httpStatus(Int)
    /// HTTP 응답이 아님 (프로토콜 위반).
    case invalidResponse
    /// 이미지 디코딩 실패 (손상/미지원 형식).
    case decodingFailed
}

public actor ImageLoader {

    public static let shared = ImageLoader()

    public typealias ProgressHandler = @Sendable (_ received: Int64, _ total: Int64) -> Void

    private let session: URLSession
    private let memoryCache: MemoryCache<UIImage>
    private let diskCache: DiskCache

    /// URL 별 공유 다운로드 + 진행률 대기자 목록.
    private struct InFlight {
        let task: Task<Data, Error>
        var observers: [UUID: ProgressHandler] = [:]
    }

    private var inFlight: [String: InFlight] = [:]

    /// - Parameters:
    ///   - session: 이미지 전용 세션을 쓰면 캐시/타임아웃을 분리할 수 있다. 기본 shared.
    ///   - memoryCache: 다운샘플된 UIImage 캐시. cost = 픽셀 바이트.
    ///   - diskCache: 원본 인코딩 Data 캐시.
    public init(
        session: URLSession = .shared,
        memoryCache: MemoryCache<UIImage> = MemoryCache(totalCostLimit: 64 * 1024 * 1024),
        diskCache: DiskCache = DiskCache(name: "ImageKit.Images", byteLimit: 256 * 1024 * 1024)
    ) {
        self.session = session
        self.memoryCache = memoryCache
        self.diskCache = diskCache
    }

    // MARK: - 로드

    public func image(
        for url: URL,
        options: ImageLoadOptions = ImageLoadOptions(),
        onProgress: ProgressHandler? = nil
    ) async throws -> ImageLoadResult {

        let memoryKey = Self.memoryKey(url: url, maxPixelSize: options.maxPixelSize)

        if !options.forceRefresh {
            if let cached = memoryCache.value(for: memoryKey) {
                return ImageLoadResult(image: cached, source: .memory)
            }

            if let data = await diskCache.data(for: url.absoluteString) {
                if let image = try? await Self.makeImage(from: data, maxPixelSize: options.maxPixelSize) {
                    storeInMemory(image, key: memoryKey)
                    return ImageLoadResult(image: image, source: .disk)
                }
                // 손상 항목 — 정리하고 네트워크로 폴백.
                await diskCache.removeData(for: url.absoluteString)
            }
        }

        let data = try await fetchData(from: url, retry: options.retry, onProgress: onProgress)
        try Task.checkCancellation()

        let image = try await Self.makeImage(from: data, maxPixelSize: options.maxPixelSize)

        await diskCache.store(data, for: url.absoluteString)
        storeInMemory(image, key: memoryKey)

        return ImageLoadResult(image: image, source: .network)
    }

    /// 메모리·디스크 캐시를 모두 비운다.
    public func clearCache() async {
        memoryCache.removeAll()
        await diskCache.removeAll()
    }

    // MARK: - 네트워크 (dedup + 재시도 + 진행률 멀티캐스트)

    private func fetchData(
        from url: URL,
        retry: RetryStrategy?,
        onProgress: ProgressHandler?
    ) async throws -> Data {

        let key = url.absoluteString

        if inFlight[key] == nil {
            // 대기자 취소와 분리된 공유 다운로드 — detached 라 actor 를 잡지도 않는다.
            let task = Task.detached { [session] () throws -> Data in
                var attempt = 0
                while true {
                    do {
                        return try await Self.download(from: url, session: session) { received, total in
                            await self.notifyProgress(key: key, received: received, total: total)
                        }
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        guard let retry, attempt < retry.maxCount else { throw error }
                        attempt += 1
                        try await Task.sleep(for: retry.interval)
                    }
                }
            }
            inFlight[key] = InFlight(task: task)
        }

        let observerID = UUID()
        if let onProgress {
            inFlight[key]?.observers[observerID] = onProgress
        }
        defer {
            // 완료 시점엔 엔트리째 사라져 있을 수 있다 — 남아 있을 때만 이탈 처리.
            inFlight[key]?.observers.removeValue(forKey: observerID)
        }

        guard let task = inFlight[key]?.task else {
            // defer 직전에 확인한 엔트리 — 도달 불가에 가깝지만 방어적으로.
            throw CancellationError()
        }

        do {
            let data = try await task.value
            inFlight.removeValue(forKey: key)
            return data
        } catch {
            inFlight.removeValue(forKey: key)
            throw error
        }
    }

    private func notifyProgress(key: String, received: Int64, total: Int64) {
        guard let observers = inFlight[key]?.observers else { return }
        for observer in observers.values {
            observer(received, total)
        }
    }

    /// 바이트 스트림 다운로드. 64KB 마다 + 완료 시 진행률을 보고한다
    /// (total 은 Content-Length, 미상이면 -1).
    @concurrent
    private static func download(
        from url: URL,
        session: URLSession,
        onProgress: @Sendable (Int64, Int64) async -> Void
    ) async throws -> Data {

        let (bytes, response) = try await session.bytes(from: url)

        guard let http = response as? HTTPURLResponse else {
            throw ImageKitError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ImageKitError.httpStatus(http.statusCode)
        }

        let total = http.expectedContentLength
        var data = Data()
        if total > 0 {
            data.reserveCapacity(Int(total))
        }

        let granularity = 64 * 1024
        var nextReport = granularity
        for try await byte in bytes {
            data.append(byte)
            if data.count >= nextReport {
                await onProgress(Int64(data.count), total)
                nextReport += granularity
            }
        }
        await onProgress(Int64(data.count), total)

        return data
    }

    // MARK: - 디코드/캐시

    /// 디코드·다운샘플 — CPU 작업이라 로더 actor 밖(@concurrent)에서 돈다.
    @concurrent
    private static func makeImage(from data: Data, maxPixelSize: CGFloat?) async throws -> UIImage {
        let image: UIImage? = if let maxPixelSize {
            ImageDownsampler.downsample(data, maxPixelSize: maxPixelSize)
        } else {
            ImageDownsampler.decode(data)
        }
        guard let image else {
            throw ImageKitError.decodingFailed
        }
        return image
    }

    private func storeInMemory(_ image: UIImage, key: String) {
        let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
        memoryCache.store(image, for: key, cost: cost)
    }

    /// 메모리 캐시는 다운샘플 결과를 담으므로 키에 크기가 들어간다.
    private static func memoryKey(url: URL, maxPixelSize: CGFloat?) -> String {
        "\(url.absoluteString)#\(maxPixelSize.map { String(Int($0.rounded())) } ?? "original")"
    }
}
