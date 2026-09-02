//
//  UploadDemoModel.swift
//  StorageSample
//
//  리허설 시나리오의 상태 기계 — 익명 로그인(JWT 확보) → 이미지 생성·업로드(티켓 +
//  PUT) → 표시 URL 발급(티켓 + 캐시). path 접두가 uid 라야 Worker 의 본인 폴더
//  검사를 통과한다 (storage RLS 의 대응물).
//

import Foundation
import Observation
import APIKit
import Supabase

@MainActor
@Observable
final class UploadDemoModel {

    enum Phase: Equatable {
        case idle
        case working(String)
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var userID: String?
    private(set) var uploadedPath: String?
    private(set) var displayURL: URL?
    /// url(for:) 재호출 시 같은 URL 이 왔는지 — SignedURLCache 적중 여부의 가시화.
    private(set) var lastLookupWasCached: Bool?

    private let storage = DemoStorageCenter.storage

    var isSignedIn: Bool { userID != nil }

    func signIn() async {
        phase = .working("익명 로그인 중")
        do {
            let auth = DemoStorageCenter.supabase.auth
            if let session = try? await auth.session {
                userID = session.user.id.uuidString.lowercased()
            } else {
                let session = try await auth.signInAnonymously()
                userID = session.user.id.uuidString.lowercased()
            }
            phase = .idle
        } catch {
            phase = .failed("로그인 실패: \(error.localizedDescription)")
        }
    }

    func upload() async {
        guard let userID else { return }
        phase = .working("이미지 생성·업로드 중")
        do {
            let path = "\(userID)/demo-\(Int(Date().timeIntervalSince1970)).jpg"
            let confirmed = try await storage.upload(
                DemoImageRenderer.makeJPEG(),
                to: DemoPrivateBucket.self,
                path: path,
                contentType: "image/jpeg"
            )
            uploadedPath = confirmed   // 반환 path = DB 저장 정본 (여기선 표시만)
            displayURL = try await storage.url(for: DemoPrivateBucket.self, path: confirmed)
            lastLookupWasCached = nil
            phase = .idle
        } catch {
            phase = .failed("업로드 실패: \(describe(error))")
        }
    }

    func refreshDisplayURL() async {
        guard let uploadedPath else { return }
        phase = .working("표시 URL 재요청 중")
        do {
            let previous = displayURL
            let url = try await storage.url(for: DemoPrivateBucket.self, path: uploadedPath)
            displayURL = url
            lastLookupWasCached = (url == previous)   // 만료 전이면 캐시 적중 = 동일 URL
            phase = .idle
        } catch {
            phase = .failed("URL 발급 실패: \(describe(error))")
        }
    }

    private func describe(_ error: any Error) -> String {
        if case let APIError.server(code, message) = error { return "\(code) — \(message)" }
        if case let APIError.unauthorized(message) = error { return "unauthorized — \(message)" }
        return error.localizedDescription
    }
}
