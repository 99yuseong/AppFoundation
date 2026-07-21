//
//  KakaoIdTokenGrant.swift
//  AppFoundation / AuthKitSupabase
//
//  ★ 격리 파일: supabase-swift 의 OpenIDConnectCredentials.Provider 에는 kakao 가
//  아직 없어(google/apple/azure/facebook만) GoTrue REST 를 직접 호출한 뒤
//  auth.setSession 으로 세션을 주입한다.
//
//  삭제 조건: supabase-swift 가 kakao id_token grant 를 지원하면 이 파일을 지우고
//  SupabaseAuthBackend.exchange 의 .kakao 분기를 signInWithIdToken 한 줄로 교체한다.
//
//  검증 구도: GoTrue 는 SHA256(요청 nonce) == id_token nonce claim 으로 검증한다.
//  Kakao SDK 에는 해시를 줬으므로 여기(GoTrue)에는 raw 를 줘야 검증이 성립한다.
//

import AuthKit
import Foundation
import os

enum KakaoIdTokenGrant {

    struct TokenPair: Decodable, Equatable {
        let accessToken: String
        let refreshToken: String

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
        }
    }

    private static let logger = Logger(subsystem: "AppFoundation", category: "AuthKit.KakaoGrant")

    /// POST `{supabaseURL}/auth/v1/token?grant_type=id_token`
    /// body: `{"provider": "kakao", "id_token": …, "nonce": rawNonce}`
    static func exchange(
        idToken: String,
        rawNonce: String,
        supabaseURL: URL,
        apiKey: String,
        additionalHeaders: [String: String] = [:],
        session: URLSession = .shared
    ) async throws -> TokenPair {

        var request = URLRequest(
            url: supabaseURL
                .appendingPathComponent("auth/v1/token")
                .appending(queryItems: [.init(name: "grant_type", value: "id_token")])
        )
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in additionalHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "provider": "kakao",
            "id_token": idToken,
            "nonce": rawNonce
        ])

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            logger.error("id_token grant 네트워크 실패: \(error.localizedDescription)")
            throw AuthKitError.backendNetwork(underlying: error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AuthKitError.unexpectedResponse(message: "HTTP 응답이 아님")
        }

        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "no body"
            logger.error("id_token grant HTTP \(http.statusCode): \(body)")
            throw AuthKitError.backendHTTP(statusCode: http.statusCode, message: body)
        }

        do {
            return try JSONDecoder().decode(TokenPair.self, from: data)
        } catch {
            throw AuthKitError.unexpectedResponse(
                message: "id_token grant 응답 디코드 실패: \(error.localizedDescription)"
            )
        }
    }
}
