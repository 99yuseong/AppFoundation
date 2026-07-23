//
//  DiskCache.swift
//  AppFoundation / CoreKit
//
//  Caches/ 하위 디렉터리에 Data 를 저장하는 디스크 캐시. 파일명은 SHA256(key) —
//  키에 URL 등 경로 부적합 문자가 와도 안전하다.
//
//  날짜 두 개로 정책을 분리한다:
//    - 생성일(creationDate)   = 저장 시각 → TTL 판정 기준 (읽기로 연장되지 않는다)
//    - 수정일(modificationDate) = 마지막 접근 → LRU 축출 순서 (읽기 히트 시 갱신)
//  축출은 store 시에만 수행한다 — byteLimit 초과분을 수정일 오래된 순으로 지운다.
//
//  캐시는 best-effort 다: 파일 I/O 실패는 miss 로 취급하고 조용히 넘어간다
//  (캐시 실패가 기능 실패로 번지지 않게).
//

import Foundation
import CryptoKit

public actor DiskCache {

    private let directory: URL
    private let byteLimit: Int
    private let ttl: TimeInterval?

    /// - Parameters:
    ///   - name: Caches/ 아래 디렉터리 이름. 용도별로 분리한다 (예: "ImageKit.Images").
    ///   - byteLimit: 총 저장량 상한(바이트). 초과분은 store 시 LRU 로 축출. 0 이면 무제한.
    ///   - ttl: 항목 유효 기간 (저장 시각 기준). nil 이면 무기한.
    public init(name: String, byteLimit: Int, ttl: Duration? = nil) {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.directory = caches.appendingPathComponent(name, isDirectory: true)
        self.byteLimit = byteLimit
        self.ttl = ttl.map {
            Double($0.components.seconds) + Double($0.components.attoseconds) / 1e18
        }
    }

    // MARK: - 읽기/쓰기

    public func data(for key: String) -> Data? {
        let url = fileURL(for: key)
        let path = url.path

        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path) else {
            return nil
        }

        // TTL: 저장 시각(생성일) 기준 — 접근으로 연장되지 않는다.
        if let ttl,
           let created = attributes[.creationDate] as? Date,
           Date().timeIntervalSince(created) > ttl {
            try? FileManager.default.removeItem(at: url)
            return nil
        }

        guard let data = try? Data(contentsOf: url) else { return nil }

        // LRU: 접근 시각을 수정일로 기록해 축출 순서를 뒤로 미룬다.
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: path)

        return data
    }

    public func store(_ data: Data, for key: String) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: fileURL(for: key), options: .atomic)
        evictIfNeeded()
    }

    public func removeData(for key: String) {
        try? FileManager.default.removeItem(at: fileURL(for: key))
    }

    public func removeAll() {
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: - 축출

    /// byteLimit 초과분을 수정일(마지막 접근) 오래된 순으로 지운다.
    private func evictIfNeeded() {
        guard byteLimit > 0 else { return }

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: .skipsHiddenFiles
        ) else { return }

        var entries: [(url: URL, modified: Date, size: Int)] = files.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                  let modified = values.contentModificationDate,
                  let size = values.fileSize
            else { return nil }
            return (url, modified, size)
        }

        var total = entries.reduce(0) { $0 + $1.size }
        guard total > byteLimit else { return }

        entries.sort { $0.modified < $1.modified }
        for entry in entries {
            guard total > byteLimit else { break }
            try? FileManager.default.removeItem(at: entry.url)
            total -= entry.size
        }
    }

    // MARK: - 경로

    private func fileURL(for key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8))
        let filename = digest.map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(filename)
    }
}
