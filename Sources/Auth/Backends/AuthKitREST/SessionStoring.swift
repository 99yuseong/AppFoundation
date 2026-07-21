//
//  SessionStoring.swift
//  AppFoundation / AuthKit (Backends 계층)
//
//  세션 저장 추상화. 기본은 Keychain(`KeychainSessionStore`) —
//  테스트/프리뷰는 `InMemorySessionStore` 를 주입한다.
//

import Foundation
import Security
import os

public protocol SessionStoring: Sendable {
    func load() -> RESTSession?
    func save(_ session: RESTSession)
    func clear()
}

// MARK: - Keychain (기본)

/// generic password 아이템 하나에 세션 JSON 을 보관한다.
public struct KeychainSessionStore: SessionStoring {

    private static let logger = Logger(subsystem: "AppFoundation", category: "AuthKit.REST")

    private let service: String
    private let account: String

    /// 한 앱에서 백엔드를 여러 개 쓰면 `service` 를 달리해 충돌을 피한다.
    public init(service: String = "AppFoundation.AuthKitREST", account: String = "session") {
        self.service = service
        self.account = account
    }

    private var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    public func load() -> RESTSession? {
        var fetch = query
        fetch[kSecReturnData as String] = true
        fetch[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(fetch as CFDictionary, &item)

        guard status == errSecSuccess, let data = item as? Data else {
            if status != errSecItemNotFound {
                Self.logger.error("Keychain 읽기 실패: \(status)")
            }
            return nil
        }
        return try? JSONDecoder().decode(RESTSession.self, from: data)
    }

    public func save(_ session: RESTSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }

        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(add as CFDictionary, nil)
        if status != errSecSuccess {
            Self.logger.error("Keychain 쓰기 실패: \(status)")
        }
    }

    public func clear() {
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - InMemory (테스트/프리뷰)

public final class InMemorySessionStore: SessionStoring, @unchecked Sendable {

    private let lock = NSLock()
    private var session: RESTSession?

    public init(session: RESTSession? = nil) {
        self.session = session
    }

    public func load() -> RESTSession? {
        lock.withLock { session }
    }

    public func save(_ session: RESTSession) {
        lock.withLock { self.session = session }
    }

    public func clear() {
        lock.withLock { session = nil }
    }
}
