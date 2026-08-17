//
//  InterstitialDemoSection.swift
//  AdSample
//
//  SDK 전면 광고 데모 — `AdMobInterstitialAdLoader` preload → present.
//  로더가 ObservableObject 가 아니므로 섹션 로컬 상태로 버튼 활성화를 구동한다.
//

import SwiftUI
import AdKitAdMob
import CoreKit

struct InterstitialDemoSection: View {

    let loader: AdMobInterstitialAdLoader

    @State private var status: DemoStatus = .idle

    var body: some View {
        Section {
            DemoStatusRow(title: "상태", status: status)
            Button {
                Task { await load() }
            } label: {
                Label("미리 로드", systemImage: "arrow.down.circle")
            }
            .disabled(status == .loading || status == .ready)
            Button {
                Task { await present() }
            } label: {
                Label("표시", systemImage: "play.rectangle")
            }
            .disabled(status != .ready)
            Button {
                Task { await loadAndPresent() }
            } label: {
                Label("로드 후 즉시 표시", systemImage: "bolt")
            }
            .disabled(status == .loading)
        } header: {
            Label("전면 광고 — SDK 풀스크린", systemImage: "play.rectangle.on.rectangle")
        } footer: {
            Text("미리 로드 → 표시, 로드 후 즉시 표시 두 패턴 모두 loadAd()/present() 조합이다. 표시 후에는 캐시가 비워진다.")
        }
    }

    private func load() async {
        status = .loading
        await loader.loadAd()
        status = loader.isAdReady ? .ready : .failure("no-fill")
    }

    private func present() async {
        guard let presenter = TopMostPresenter.topViewController() else { return }
        do {
            try await loader.present(from: presenter)
            status = .idle
        } catch {
            status = .failure(demoErrorText(error))
        }
    }

    /// 온디맨드 패턴 — 캐시가 있으면 loadAd() 가 no-op 이라 그대로 즉시 표시된다.
    private func loadAndPresent() async {
        status = .loading
        await loader.loadAd()
        guard loader.isAdReady else {
            status = .failure("no-fill")
            return
        }
        await present()
    }
}
