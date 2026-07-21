//
//  AuthSampleApp.swift
//  AuthSample
//
//  AppFoundation AuthKit 데모. 기본은 MockAuthService 라 콘솔 설정 없이 바로
//  실행된다. 실서비스(Supabase) 연결은 LiveAuthAssembly.swift 참조.
//

import AuthKit
import SwiftUI

@main
struct AuthSampleApp: App {

    // 실서비스 연결 시 LiveAuthAssembly.makeLiveAuthService() 로 교체
    static let auth: any AuthService = MockAuthService()

    var body: some Scene {
        WindowGroup {
            TabView {
                LoginView(auth: Self.auth)
                    .tabItem { Label("SwiftUI", systemImage: "swift") }

                UIKitLoginScreen(auth: Self.auth)
                    .tabItem { Label("UIKit", systemImage: "square.stack") }
            }
            .onOpenURL { url in
                // OAuth 콜백 (카카오톡 앱 스위치, Google 등)
                _ = Self.auth.handle(url)
            }
        }
    }
}
