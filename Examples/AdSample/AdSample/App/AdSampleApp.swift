//
//  AdSampleApp.swift
//  AdSample
//
//  AppFoundation AdKit·AdKitAdMob 데모. Google 테스트 App ID/unit ID 로 도니
//  콘솔 설정 없이 바로 실행된다.
//

import SwiftUI

@main
struct AdSampleApp: App {

    @StateObject private var adCenter = DemoAdCenter()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(adCenter)
                .task { await adCenter.startIfNeeded() }
        }
    }
}
