//
//  ATTDemoSection.swift
//  AdSample
//
//  ATT(앱 추적 투명성) 데모 — `ATTAuthorization` 상태 조회·권한 요청.
//

import SwiftUI
import AdKit

struct ATTDemoSection: View {

    @State private var status = ATTAuthorization.status

    var body: some View {
        Section {
            LabeledContent("상태") {
                DemoStatusBadge(status: badgeStatus)
            }
            Button {
                Task {
                    await ATTAuthorization.request()
                    status = ATTAuthorization.status
                }
            } label: {
                Label("권한 요청", systemImage: "hand.raised")
            }
            .disabled(status != .notDetermined)
        } header: {
            Label("ATT — 앱 추적 투명성", systemImage: "person.badge.shield.checkmark")
        } footer: {
            Text("시스템 프롬프트는 미결정 상태에서 1회만 뜬다. 다시 보려면 앱을 삭제 후 재설치한다.")
        }
    }

    private var badgeStatus: DemoStatus {
        switch status {
        case .notDetermined: .note("미결정")
        case .authorized:    .success("허용됨")
        case .denied:        .failure("거부됨")
        }
    }
}
