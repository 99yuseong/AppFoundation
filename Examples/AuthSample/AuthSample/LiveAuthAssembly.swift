//
//  LiveAuthAssembly.swift
//  AuthSample
//
//  실서비스(Supabase) 조립 예시. 기본은 비활성(#if LIVE_AUTH) — 사용하려면:
//
//  1. docs/auth/00-overview.md 체크리스트로 콘솔(Apple/Kakao/Google/Supabase) 설정
//  2. 앱 타겟에 supabase-swift 의 `Supabase` product 추가 (SupabaseClient 타입용)
//  3. Info.plist 에 키 추가: SUPABASE_PROJECT_ID, SUPABASE_API_KEY,
//     KAKAO_APP_KEY, GOOGLE_CLIENT_ID + URL scheme (docs/auth/05 참조)
//  4. Build Settings 의 Active Compilation Conditions 에 LIVE_AUTH 추가
//  5. AuthSampleApp.auth 를 LiveAuthAssembly.makeLiveAuthService() 로 교체
//

#if LIVE_AUTH

import AuthKit
import AuthKitGoogle
import AuthKitKakao
import AuthKitSupabase
import CoreKit
import Foundation
import Supabase

enum LiveAuthAssembly {

    static func makeLiveAuthService() -> any AuthService {

        let supabaseURL = URL(string: "https://\(ConfigValues.require("SUPABASE_PROJECT_ID")).supabase.co")!
        let supabaseKey = ConfigValues.require("SUPABASE_API_KEY")

        // ⚠️ 앱 전역에 SupabaseClient 는 하나 — 실제 앱에선 기존 클라이언트를 주입한다.
        let client = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseKey)

        // 앱 launch 시 1회 (예: App.init)
        // KakaoAuthProvider.initialize(appKey: ConfigValues.require("KAKAO_APP_KEY"))

        return DefaultAuthService(
            backend: SupabaseAuthBackend(
                client: client,
                configuration: .init(supabaseURL: supabaseURL, apiKey: supabaseKey)
            ),
            providers: [
                AppleAuthProvider(),
                KakaoAuthProvider(),
                GoogleAuthProvider(clientID: ConfigValues.require("GOOGLE_CLIENT_ID")),
            ]
        )
    }
}

#endif
