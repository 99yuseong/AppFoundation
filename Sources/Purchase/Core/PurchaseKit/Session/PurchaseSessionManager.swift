//
//  PurchaseSessionManager.swift
//  AppFoundation / PurchaseKit
//
//  `PurchaseSessionManaging` 기본 구현 (Doran PurchaseSessionManager 이식·일반화).
//  configure 는 이 actor 가 1회 소유한다 — 도메인들이 각자 configure 하지 않는다.
//

import Foundation
import os

public actor PurchaseSessionManager: PurchaseSessionManaging {

    private let purchaseService: any PurchaseService
    private let userIDProvider: @Sendable () async throws -> String
    private let validateUserID: @Sendable (String) -> Bool

    private var isConfigured = false
    /// 현재 signIn 된 서비스 유저 id(원문). nil = 익명(또는 미로그인).
    private var signedInUserID: String?

    private let logger = Logger(subsystem: "AppFoundation", category: "PurchaseSession")

    /// - Parameters:
    ///   - purchaseService: 백엔드 서비스. configure 는 이 매니저가 호출한다.
    ///   - userIDProvider: self-heal 시 현재 서비스 유저 id 를 조회한다 (미로그인이면 throw).
    ///   - validateUserID: id 형식 검증. 실패하면 identity 를 세우지 않는다.
    ///     기본값은 비어있지 않음. 서버 id 가 uuid 라면 `{ UUID(uuidString: $0) != nil }` 을 넘긴다 —
    ///     검증만 하고 값은 **원문** 을 쓴다(`uuidString` 왕복 금지).
    public init(
        purchaseService: any PurchaseService,
        userIDProvider: @escaping @Sendable () async throws -> String,
        validateUserID: @escaping @Sendable (String) -> Bool = { !$0.isEmpty }
    ) {
        self.purchaseService = purchaseService
        self.userIDProvider = userIDProvider
        self.validateUserID = validateUserID
    }

    public func login(userID: String) async {
        await serialized { await self.performLogin(userID: userID) }
    }

    public func logout() async {
        await serialized { await self.performLogout() }
    }

    public func ensureConfigured() async {
        await serialized { await self.performEnsureConfigured() }
    }

    public func ensureSignedIn() async throws {
        try await serializedThrowing { try await self.performEnsureSignedIn() }
    }

    // MARK: - 직렬화

    // actor 는 suspend 지점(await SDK 호출)에서 다른 호출이 끼어들 수 있다(reentrancy).
    // login/logout 은 계정 피처의 독립 fire-and-forget effect 라 동시 도착이 가능한데,
    // 인터리빙되면 SDK 반영 순서와 signedInUserID 기록이 어긋나 "매니저는 로그인·SDK 는
    // 익명" 조합 — 구매가 익명으로 나가 지급이 누락되는 사고 — 이 생긴다.
    // 모든 공개 연산을 FIFO 로 이어 한 번에 하나만 SDK 상태를 만지게 한다.
    // ⚠️ perform* 내부에서는 공개 메서드가 아니라 perform* 을 직접 부른다(재enqueue 는 데드락).

    /// 직렬화 큐의 꼬리 — 새 연산은 이전 연산 완료를 기다린 뒤 실행된다.
    private var tail: Task<Void, Never>?

    private func serialized(_ operation: @escaping @Sendable () async -> Void) async {
        let previous = tail
        let task = Task {
            await previous?.value
            await operation()
        }
        tail = task
        await task.value
    }

    private func serializedThrowing(_ operation: @escaping @Sendable () async throws -> Void) async throws {
        let previous = tail
        let task = Task {
            await previous?.value
            try await operation()
        }
        tail = Task { try? await task.value }
        try await task.value
    }

    // MARK: - 연산 본체 (직렬화 큐 안에서만 실행)

    private func performLogin(userID: String) async {
        guard validateUserID(userID) else {
            logger.error("서비스 유저 id 검증 실패 — 결제 identity 미설정: \(userID, privacy: .private)")
            return
        }
        // 로그인 준비는 한 로그인에 두 번 탈 수 있다 — 멱등.
        guard signedInUserID != userID else { return }

        await performEnsureConfigured()
        // 유저 전환 중 signIn 이 실패하면 이전 id 가 남아 ensureSignedIn 이 통과해 구매가
        // 이전 계정에 귀속된다 — 시도 전에 로컬 identity 를 무효화한다.
        signedInUserID = nil
        do {
            try await purchaseService.signIn(appUserID: userID)
            signedInUserID = userID
            logger.info("✅ Purchase signIn — appUserID=\(userID, privacy: .private)")
        } catch {
            logger.error("Purchase signIn 실패(구매 전 self-heal 로 재시도): \(error)")
        }
    }

    private func performLogout() async {
        guard isConfigured, signedInUserID != nil else { return }
        do {
            try await purchaseService.signOut()
            signedInUserID = nil
            logger.info("Purchase signOut — 익명 복귀")
        } catch {
            // 실패해도 다음 login 의 signIn 이 identity 를 덮어쓴다.
            logger.error("Purchase signOut 실패: \(error)")
        }
    }

    private func performEnsureConfigured() async {
        guard !isConfigured else { return }
        let cached = await purchaseService.configure()
        isConfigured = true
        // 백엔드가 캐시 id 로 부팅해 이미 식별돼 있으면(RevenueCat appUserID 설정) 로컬 기록을
        // 맞춘다 — 아니면 logout 이 no-op 돼 identity 가 잔류한다.
        if let cached, !cached.isAnonymous, signedInUserID == nil {
            signedInUserID = cached.appUserId
        }
    }

    private func performEnsureSignedIn() async throws {
        guard signedInUserID == nil else { return }

        // self-heal — 로그인 effect 실패/배선 누락이어도 구매가 익명으로 나가지 않게.
        let userID: String
        do {
            userID = try await userIDProvider()
        } catch {
            throw PurchaseSessionError.identityUnavailable
        }
        guard validateUserID(userID) else {
            logger.error("ensureSignedIn — 서비스 유저 id 검증 실패: \(userID, privacy: .private)")
            throw PurchaseSessionError.identityUnavailable
        }
        await performEnsureConfigured()
        try await purchaseService.signIn(appUserID: userID)
        signedInUserID = userID
        logger.info("✅ Purchase signIn(self-heal) — appUserID=\(userID, privacy: .private)")
    }
}
