//
//  AdMobConfigurator.swift
//  AppFoundation / AdKitAdMob
//
//  Google Mobile Ads SDK 를 시작하고 개발 빌드가 테스트 광고를 받도록 테스트
//  기기를 등록한다. 테스트 기기 ID 목록은 앱이 공급한다 — SPM 패키지는 앱의
//  DEV 컴파일 조건을 볼 수 없으므로 앱이 빌드 조건(#if DEBUG || DEV)으로
//  거른다. 빈 목록은 no-op 이라 아무것도 넘기지 않는 릴리즈 빌드는 영향이 없다.
//
//  AdMob App ID(`GADApplicationIdentifier`)는 SDK 가 앱 Info.plist 에서 직접
//  읽는다 — 앱이 Xcode 에서 설정한다 (xcconfig 변수 주입 권장, docs/ad 참고).
//

import UIKit
import GoogleMobileAds
import os

@MainActor
public struct AdMobConfigurator {

    /// 테스트 광고를 받을 기기 식별자 목록.
    let testDeviceIdentifiers: [String]

    /// true 면 오디오 세션을 앱이 관리한다고 SDK 에 알린다. 영상 광고가
    /// AVAudioSession 을 .ambient 로 재구성해 무음 기기에서 앱 오디오(음성 재생
    /// 등)를 침묵시키는 것을 막는다. 오디오를 직접 다루는 앱만 켠다.
    /// (`isApplicationMuted` 는 건드리지 않는다 — 보상형 광고는 소리가 필요하다.)
    let managesAudioSessionForVideoAds: Bool

    private let log = Logger(subsystem: "AppFoundation", category: "AdKitAdMob")

    public init(
        testDeviceIdentifiers: [String] = [],
        managesAudioSessionForVideoAds: Bool = false
    ) {
        self.testDeviceIdentifiers = testDeviceIdentifiers
        self.managesAudioSessionForVideoAds = managesAudioSessionForVideoAds
    }

    /// SDK 를 시작한다. 광고를 처음 로드하기 전에 1회 호출한다.
    public func configure() async {
        registerTestDevices()
        if managesAudioSessionForVideoAds {
            MobileAds.shared.audioVideoManager.isAudioSessionApplicationManaged = true
        }
        await MobileAds.shared.start()
    }

    private func registerTestDevices() {
        // 빈 목록 = no-op — Prod 는 앱이 목록을 안 넘겨(#if DEBUG || DEV) 여기서 끝난다.
        guard !testDeviceIdentifiers.isEmpty else { return }
        // GMA 의 테스트 기기 id 는 이 기기의 IDFV — 앱 삭제/재설치로 바뀔 수 있어
        // 현재 값을 찍어 등록 목록과 대조할 수 있게 한다.
        let idfv = UIDevice.current.identifierForVendor?.uuidString ?? "(없음)"
        log.info("테스트 기기 IDFV: \(idfv) — 등록 목록: \(testDeviceIdentifiers.joined(separator: ", "))")
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = testDeviceIdentifiers
    }
}
