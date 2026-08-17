//
//  ContentView.swift
//  AdSample
//
//  AdKit·AdKitAdMob 데모 메뉴 — 전면형 네이티브(기본 템플릿, SwiftUI/UIKit),
//  상주 배너(커스텀 레이아웃), SDK 전면, 보상형, ATT.
//

import SwiftUI
import AdKit
import AdKitAdMob
import CoreKit

struct ContentView: View {

    @EnvironmentObject private var adCenter: DemoAdCenter

    @State private var isShowingNativeInterstitial = false
    @State private var nativeStatus = "미로드"
    @State private var interstitialStatus = "미로드"
    @State private var rewardedStatus = "-"
    @State private var attStatusText = Self.describeATTStatus()

    var body: some View {
        NavigationStack {
            List {
                nativeInterstitialSection
                BannerDemoSection(loader: adCenter.banner)
                interstitialSection
                rewardedSection
                attSection
            }
            .navigationTitle("AdSample")
        }
        .fullScreenCover(isPresented: $isShowingNativeInterstitial) {
            NativeAdInterstitialView(adLoader: adCenter.nativeInterstitial)
                .setCloseButtonUnlockInterval(3)
                .setPromotionButtonTitle("광고 없이 이용하기 (데모)")
                .setOnClose {
                    isShowingNativeInterstitial = false
                    nativeStatus = "미로드"
                }
                .setOnAdNotReady { isShowingNativeInterstitial = false }
                .setOnPromotionTapped { print("promotion tapped") }
                .ignoresSafeArea()
        }
    }

    // MARK: - 전면형 네이티브 (기본 템플릿)

    private var nativeInterstitialSection: some View {
        Section {
            LabeledContent("상태", value: nativeStatus)
            Button("미리 로드") {
                Task {
                    nativeStatus = "로드 중…"
                    await adCenter.nativeInterstitial.loadAd()
                    nativeStatus = adCenter.nativeInterstitial.isAdReady ? "준비됨" : "실패(no-fill)"
                }
            }
            Button("SwiftUI 로 표시 (fullScreenCover)") {
                isShowingNativeInterstitial = true
            }
            .disabled(!adCenter.nativeInterstitial.isAdReady)
            Button("UIKit 으로 표시 (present)") {
                presentNativeInterstitialUIKit()
            }
            .disabled(!adCenter.nativeInterstitial.isAdReady)
        } header: {
            Text("전면형 네이티브 — 기본 템플릿")
        } footer: {
            Text("InterstitialNativeAdTemplateUIView + 카운트다운 닫기. 표시하면 캐시가 소비되어 다시 로드해야 한다.")
        }
    }

    private func presentNativeInterstitialUIKit() {
        let controller = NativeAdInterstitialViewController(adLoader: adCenter.nativeInterstitial)
            .setCloseButtonUnlockInterval(3)
        controller.onCloseButtonTapped = { nativeStatus = "미로드" }
        TopMostPresenter.topViewController()?.present(controller, animated: true)
    }

    // MARK: - SDK 전면

    private var interstitialSection: some View {
        Section("전면 광고 (SDK 풀스크린)") {
            LabeledContent("상태", value: interstitialStatus)
            Button("미리 로드") {
                Task {
                    interstitialStatus = "로드 중…"
                    await adCenter.interstitial.loadAd()
                    interstitialStatus = adCenter.interstitial.isAdReady ? "준비됨" : "실패"
                }
            }
            Button("표시") {
                Task {
                    guard let presenter = TopMostPresenter.topViewController() else { return }
                    do {
                        try await adCenter.interstitial.present(from: presenter)
                        interstitialStatus = "미로드"
                    } catch {
                        interstitialStatus = "표시 실패: \(error)"
                    }
                }
            }
            .disabled(!adCenter.interstitial.isAdReady)
        }
    }

    // MARK: - 보상형

    private var rewardedSection: some View {
        Section {
            LabeledContent("결과", value: rewardedStatus)
            Button("시청하기 (로드 → 즉시 표시)") {
                Task {
                    rewardedStatus = "로드 중…"
                    await adCenter.rewarded.loadAd()
                    guard let presenter = TopMostPresenter.topViewController() else { return }
                    do {
                        let earned = try await adCenter.rewarded.present(from: presenter, userID: nil)
                        rewardedStatus = earned ? "시청 완료 — 보상 지급 대상" : "중도 이탈"
                    } catch {
                        rewardedStatus = "실패: \(error)"
                    }
                }
            }
        } header: {
            Text("보상형 광고")
        } footer: {
            Text("온디맨드 패턴 — 탭 시점에 로드해 즉시 표시한다. 실서비스에서는 userID 를 넘겨 SSV 로 서버가 지급한다.")
        }
    }

    // MARK: - ATT

    private var attSection: some View {
        Section("ATT (앱 추적 투명성)") {
            LabeledContent("상태", value: attStatusText)
            Button("권한 요청") {
                Task {
                    await ATTAuthorization.request()
                    attStatusText = Self.describeATTStatus()
                }
            }
        }
    }

    private static func describeATTStatus() -> String {
        switch ATTAuthorization.status {
        case .notDetermined: return "미결정"
        case .authorized:    return "허용됨"
        case .denied:        return "거부됨"
        }
    }
}

// MARK: - 상주 배너 (커스텀 레이아웃)

/// 로더의 @Published 를 직접 관찰하기 위해 분리한 서브뷰.
private struct BannerDemoSection: View {

    @ObservedObject var loader: AdMobPersistentNativeAdLoader

    var body: some View {
        Section {
            NativeAdHostView(ad: loader.shouldShowAd ? loader.currentAd : nil) {
                DemoBannerAdLayoutView()
            }
            .frame(height: 72)
            Button("배너 로드") {
                Task { await loader.loadAds() }
            }
        } header: {
            Text("상주 네이티브 배너 — 커스텀 레이아웃")
        } footer: {
            Text("NativeAdLayoutUIView 서브클래스(DemoBannerAdLayoutView)를 NativeAdHostView 에 주입. 로드 전에는 기본(no-fill) 콘텐츠가 보인다.")
        }
    }
}
