//
//  RewardedDemoSection.swift
//  AdSample
//
//  보상형 광고 데모 — 온디맨드 패턴: 탭 시점에 로드해 즉시 표시한다.
//  섹션은 Core 계약(`RewardedAdLoading`)에만 의존한다 — AdMob 구현체는
//  조립부(DemoAdCenter)가 주입하고, 이 파일은 AdKit 만 import 한다.
//  실서비스에서는 userID 를 넘겨 SSV 로 서버가 보상을 지급한다.
//

import SwiftUI
import AdKit
import CoreKit

struct RewardedDemoSection: View {

    let loader: any RewardedAdLoading

    @State private var status: DemoStatus = .idle

    var body: some View {
        Section {
            DemoStatusRow(title: "상태", status: status)
            Button {
                Task { await preload() }
            } label: {
                Label("미리 로드", systemImage: "arrow.down.circle")
            }
            .disabled(status == .loading || loader.isAdReady)
            Button {
                Task { await watch() }
            } label: {
                Label("시청하기 — 캐시 있으면 즉시, 없으면 로드 후 표시", systemImage: "play.circle")
            }
            .disabled(status == .loading)
        } header: {
            Label("보상형 광고", systemImage: "gift.fill")
        } footer: {
            Text("권장은 온디맨드(시청하기만) — AdMob 노출률(show rate)을 지킨다. 미리 로드도 지원되며, 캐시는 다음 시청에서 즉시 재생된다.")
        }
    }

    private func preload() async {
        status = .loading
        do {
            try await loader.loadAd()
            status = .ready
        } catch {
            status = .failure(demoErrorText(error))
        }
    }

    private func watch() async {
        status = .loading
        guard let presenter = TopMostPresenter.topViewController() else { return }
        do {
            try await loader.loadAd()
            let earned = try await loader.present(from: presenter, userID: nil)
            status = earned ? .success("시청 완료 — 보상 지급 대상") : .failure("중도 이탈")
        } catch {
            status = .failure(demoErrorText(error))
        }
    }
}
