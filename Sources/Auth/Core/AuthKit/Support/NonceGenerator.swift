//
//  NonceGenerator.swift
//  AppFoundation / AuthKit
//

import Foundation
import CryptoKit

/// OIDC 로그인 재전송 공격 방지용 nonce 생성기.
///
/// 사용 구도(Apple·Kakao 공통): SDK 요청에는 `sha256(raw)` 를 주고, 백엔드 검증에는
/// `raw` 를 준다 — 백엔드(GoTrue)가 SHA256(요청 nonce) == id_token nonce claim 으로
/// 검증하기 때문.
public enum NonceGenerator {

    /// URL-safe 랜덤 nonce 문자열 생성.
    public static func random(length: Int = 32) -> String {
        precondition(length > 0, "nonce length는 0보다 커야 합니다")

        // 정확히 64자 (A–Z에서 W 제외) — 256 % 64 == 0이라 modulo bias가 없다
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)

        guard status == errSecSuccess else {
            // SecRandom 실패 시 시스템 제공 난수로 폴백
            return String((0..<length).map { _ in charset.randomElement()! })
        }

        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    /// SHA256 해시의 hex 문자열 (SDK 요청 nonce 용).
    public static func sha256(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
